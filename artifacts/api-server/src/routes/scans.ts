import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  scanJobsTable,
  scanResultsTable,
  scanProfilesTable,
  targetsTable,
} from "@workspace/db/schema";
import { eq, and, desc, or } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { logAudit } from "../lib/audit";
import { consumeScanAttempt } from "../lib/rate-limiter";
import { z } from "zod";

const router: IRouter = Router();

const createScanSchema = z.object({
  targetId: z.string().uuid(),
  tool: z.enum([
    "nmap",
    "masscan",
    "arp-scan",
    "dns",
    "nikto",
    "nuclei",
    "whatweb",
    "openssl",
    "testssl",
    "gobuster",
    "amass",
    "subfinder",
    "whois",
    "shodan",
    "virustotal",
  ]),
  profileId: z.string().uuid().optional(),
  flags: z.string().default(""),
});

router.get("/scans", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { targetId, tool, status } = req.query;

  let query = db
    .select({
      job: scanJobsTable,
      targetAddress: targetsTable.address,
      targetName: targetsTable.name,
    })
    .from(scanJobsTable)
    .leftJoin(targetsTable, eq(scanJobsTable.targetId, targetsTable.id))
    .where(eq(scanJobsTable.userId, req.user!.sub))
    .$dynamic();

  const conditions = [eq(scanJobsTable.userId, req.user!.sub)];
  if (targetId) conditions.push(eq(scanJobsTable.targetId, targetId as string));
  if (tool) conditions.push(eq(scanJobsTable.tool, tool as any));
  if (status) conditions.push(eq(scanJobsTable.status, status as any));

  const jobs = await db
    .select({
      job: scanJobsTable,
      targetAddress: targetsTable.address,
      targetName: targetsTable.name,
    })
    .from(scanJobsTable)
    .leftJoin(targetsTable, eq(scanJobsTable.targetId, targetsTable.id))
    .where(and(...conditions))
    .orderBy(desc(scanJobsTable.createdAt))
    .limit(100);

  res.json(jobs);
});

router.post("/scans", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createScanSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }
  const { targetId, tool, profileId, flags } = parsed.data;

  const target = await db
    .select()
    .from(targetsTable)
    .where(and(eq(targetsTable.id, targetId), eq(targetsTable.userId, req.user!.sub)))
    .limit(1);

  if (!target.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  if (target[0].authorizationStatus !== "authorized") {
    res.status(403).json({ error: "Target must be authorized before scanning" });
    return;
  }

  const allowed = await consumeScanAttempt(req.user!.sub, targetId, res);
  if (!allowed) return;

  const [job] = await db
    .insert(scanJobsTable)
    .values({
      userId: req.user!.sub,
      targetId,
      tool,
      profileId,
      flags,
      status: "pending",
    })
    .returning();

  await logAudit(
    { userId: req.user!.sub, targetId, action: "scan_requested", tool },
    req,
  );

  res.status(201).json(job);
});

router.get("/scans/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const jobs = await db
    .select()
    .from(scanJobsTable)
    .where(
      and(eq(scanJobsTable.id, req.params.id), eq(scanJobsTable.userId, req.user!.sub)),
    )
    .limit(1);

  if (!jobs.length) {
    res.status(404).json({ error: "Scan job not found" });
    return;
  }
  res.json(jobs[0]);
});

router.get("/scans/:id/results", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const jobs = await db
    .select({ id: scanJobsTable.id })
    .from(scanJobsTable)
    .where(
      and(eq(scanJobsTable.id, req.params.id), eq(scanJobsTable.userId, req.user!.sub)),
    )
    .limit(1);

  if (!jobs.length) {
    res.status(404).json({ error: "Scan job not found" });
    return;
  }

  const results = await db
    .select()
    .from(scanResultsTable)
    .where(eq(scanResultsTable.scanJobId, req.params.id))
    .limit(1);

  res.json(results[0] ?? null);
});

router.delete("/scans/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const jobs = await db
    .select()
    .from(scanJobsTable)
    .where(
      and(eq(scanJobsTable.id, req.params.id), eq(scanJobsTable.userId, req.user!.sub)),
    )
    .limit(1);

  if (!jobs.length) {
    res.status(404).json({ error: "Scan job not found" });
    return;
  }

  if (jobs[0].status === "running") {
    res.status(400).json({ error: "Cannot delete a running scan. Cancel it first." });
    return;
  }

  await db
    .update(scanJobsTable)
    .set({ status: "cancelled" })
    .where(eq(scanJobsTable.id, req.params.id));

  res.status(204).send();
});

router.get("/scan-profiles", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const profiles = await db
    .select()
    .from(scanProfilesTable)
    .where(or(eq(scanProfilesTable.userId, req.user!.sub), eq(scanProfilesTable.isSystem, true)))
    .orderBy(desc(scanProfilesTable.isSystem), desc(scanProfilesTable.createdAt));

  res.json(profiles);
});

router.post("/scan-profiles", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const schema = z.object({
    name: z.string().min(1).max(100),
    tool: z.enum(["nmap", "masscan", "arp-scan", "dns", "nikto", "nuclei", "whatweb", "openssl", "testssl", "gobuster", "amass", "subfinder", "whois", "shodan", "virustotal"]),
    flags: z.string().default(""),
    description: z.string().optional(),
    isDefault: z.boolean().default(false),
  });

  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const [profile] = await db
    .insert(scanProfilesTable)
    .values({ ...parsed.data, userId: req.user!.sub })
    .returning();

  res.status(201).json(profile);
});

router.delete("/scan-profiles/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(scanProfilesTable)
    .where(
      and(
        eq(scanProfilesTable.id, req.params.id),
        eq(scanProfilesTable.userId, req.user!.sub),
        eq(scanProfilesTable.isSystem, false),
      ),
    )
    .returning({ id: scanProfilesTable.id });

  if (!deleted) {
    res.status(404).json({ error: "Profile not found or cannot be deleted" });
    return;
  }
  res.status(204).send();
});

export default router;
