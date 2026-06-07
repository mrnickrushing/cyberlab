import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  targetsTable,
  type InsertTarget,
} from "@workspace/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { logAudit } from "../lib/audit";
import { z } from "zod";

const router: IRouter = Router();

const createTargetSchema = z.object({
  name: z.string().min(1).max(200),
  type: z.enum(["ip", "domain", "subnet", "webapp"]),
  address: z.string().min(1),
  owner: z.string().optional(),
  authorizationStatus: z.enum(["authorized", "unauthorized", "pending"]).default("pending"),
  riskLevel: z.enum(["critical", "high", "medium", "low", "info"]).default("info"),
  tags: z.array(z.string()).default([]),
  scopeNotes: z.string().optional(),
  allowedIpRanges: z.array(z.string()).default([]),
});

const updateTargetSchema = createTargetSchema.partial();

router.get("/targets", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const targets = await db
    .select()
    .from(targetsTable)
    .where(eq(targetsTable.userId, req.user!.sub))
    .orderBy(desc(targetsTable.createdAt));
  res.json(targets);
});

router.post("/targets", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createTargetSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const [target] = await db
    .insert(targetsTable)
    .values({ ...parsed.data, userId: req.user!.sub })
    .returning();

  await logAudit({ userId: req.user!.sub, targetId: target.id, action: "target_created" }, req);
  res.status(201).json(target);
});

router.get("/targets/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const targets = await db
    .select()
    .from(targetsTable)
    .where(and(eq(targetsTable.id, req.params.id), eq(targetsTable.userId, req.user!.sub)))
    .limit(1);

  if (!targets.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }
  res.json(targets[0]);
});

router.patch("/targets/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = updateTargetSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const [updated] = await db
    .update(targetsTable)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(and(eq(targetsTable.id, req.params.id), eq(targetsTable.userId, req.user!.sub)))
    .returning();

  if (!updated) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  await logAudit({ userId: req.user!.sub, targetId: updated.id, action: "target_updated" }, req);
  res.json(updated);
});

router.post("/targets/:id/archive", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [updated] = await db
    .update(targetsTable)
    .set({ isArchived: true, updatedAt: new Date() })
    .where(and(eq(targetsTable.id, req.params.id), eq(targetsTable.userId, req.user!.sub)))
    .returning();

  if (!updated) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  await logAudit({ userId: req.user!.sub, targetId: updated.id, action: "target_archived" }, req);
  res.json(updated);
});

router.delete("/targets/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(targetsTable)
    .where(and(eq(targetsTable.id, req.params.id), eq(targetsTable.userId, req.user!.sub)))
    .returning({ id: targetsTable.id });

  if (!deleted) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  await logAudit({ userId: req.user!.sub, targetId: deleted.id, action: "target_deleted" }, req);
  res.status(204).send();
});

export default router;
