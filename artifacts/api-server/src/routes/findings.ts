import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  findingsTable,
  findingEventsTable,
  targetsTable,
} from "@workspace/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { logAudit } from "../lib/audit";
import { z } from "zod";

const router: IRouter = Router();

const createFindingSchema = z.object({
  targetId: z.string().uuid(),
  scanJobId: z.string().uuid().optional(),
  title: z.string().min(1).max(500),
  cveId: z.string().optional(),
  severity: z.enum(["critical", "high", "medium", "low", "info"]).default("info"),
  cvssScore: z.number().min(0).max(10).optional(),
  owaspCategory: z.string().optional(),
  description: z.string().optional(),
  remediation: z.string().optional(),
  references: z.array(z.string()).default([]),
  notes: z.string().optional(),
});

const updateFindingSchema = z.object({
  status: z.enum(["open", "fixed", "accepted_risk", "false_positive"]).optional(),
  notes: z.string().optional(),
  remediation: z.string().optional(),
  severity: z.enum(["critical", "high", "medium", "low", "info"]).optional(),
  note: z.string().optional(),
});

router.get("/findings", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { targetId, status, severity } = req.query;

  const conditions = [eq(findingsTable.userId, req.user!.sub)];
  if (targetId) conditions.push(eq(findingsTable.targetId, targetId as string));
  if (status) conditions.push(eq(findingsTable.status, status as any));
  if (severity) conditions.push(eq(findingsTable.severity, severity as any));

  const findings = await db
    .select({
      finding: findingsTable,
      targetName: targetsTable.name,
      targetAddress: targetsTable.address,
    })
    .from(findingsTable)
    .leftJoin(targetsTable, eq(findingsTable.targetId, targetsTable.id))
    .where(and(...conditions))
    .orderBy(desc(findingsTable.createdAt));

  res.json(findings);
});

router.post("/findings", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createFindingSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const target = await db
    .select({ id: targetsTable.id })
    .from(targetsTable)
    .where(and(eq(targetsTable.id, parsed.data.targetId), eq(targetsTable.userId, req.user!.sub)))
    .limit(1);

  if (!target.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const [finding] = await db
    .insert(findingsTable)
    .values({ ...parsed.data, userId: req.user!.sub })
    .returning();

  await logAudit({ userId: req.user!.sub, targetId: finding.targetId, action: "finding_updated", details: `Created: ${finding.title}` }, req);
  res.status(201).json(finding);
});

router.get("/findings/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const findings = await db
    .select()
    .from(findingsTable)
    .where(and(eq(findingsTable.id, req.params.id), eq(findingsTable.userId, req.user!.sub)))
    .limit(1);

  if (!findings.length) {
    res.status(404).json({ error: "Finding not found" });
    return;
  }
  res.json(findings[0]);
});

router.patch("/findings/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = updateFindingSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const existing = await db
    .select()
    .from(findingsTable)
    .where(and(eq(findingsTable.id, req.params.id), eq(findingsTable.userId, req.user!.sub)))
    .limit(1);

  if (!existing.length) {
    res.status(404).json({ error: "Finding not found" });
    return;
  }

  const { note, ...updateData } = parsed.data;
  const resolvedAt = updateData.status === "fixed" ? new Date() : undefined;

  const [updated] = await db
    .update(findingsTable)
    .set({ ...updateData, ...(resolvedAt ? { resolvedAt } : {}), updatedAt: new Date() })
    .where(eq(findingsTable.id, req.params.id))
    .returning();

  if (updateData.status && updateData.status !== existing[0].status) {
    await db.insert(findingEventsTable).values({
      findingId: req.params.id,
      userId: req.user!.sub,
      previousStatus: existing[0].status,
      newStatus: updateData.status,
      note,
    });
  }

  await logAudit({ userId: req.user!.sub, targetId: updated.targetId, action: "finding_updated" }, req);
  res.json(updated);
});

router.get("/findings/:id/timeline", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const finding = await db
    .select({ id: findingsTable.id })
    .from(findingsTable)
    .where(and(eq(findingsTable.id, req.params.id), eq(findingsTable.userId, req.user!.sub)))
    .limit(1);

  if (!finding.length) {
    res.status(404).json({ error: "Finding not found" });
    return;
  }

  const events = await db
    .select()
    .from(findingEventsTable)
    .where(eq(findingEventsTable.findingId, req.params.id))
    .orderBy(desc(findingEventsTable.createdAt));

  res.json(events);
});

router.delete("/findings/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(findingsTable)
    .where(and(eq(findingsTable.id, req.params.id), eq(findingsTable.userId, req.user!.sub)))
    .returning({ id: findingsTable.id });

  if (!deleted) {
    res.status(404).json({ error: "Finding not found" });
    return;
  }
  res.status(204).send();
});

export default router;
