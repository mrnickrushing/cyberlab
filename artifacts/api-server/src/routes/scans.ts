import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  scanJobsTable,
  scanResultsTable,
  scanProfilesTable,
  targetsTable,
  usersTable,
  findingsTable,
} from "@workspace/db/schema";
import { eq, and, desc, or, gte, lte, inArray } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { logAudit } from "../lib/audit";
import { consumeScanAttempt } from "../lib/rate-limiter";
import { enqueueScanJob } from "../lib/queue";
import { isPrivateIp } from "../lib/ip-utils";
import { isAddressInRanges } from "../lib/cidr";
import { z } from "zod";

const router: IRouter = Router();

const LAB_ONLY_MODE = process.env.LAB_ONLY_MODE === "true";

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

const SEVERITY_ORDER = ["info", "low", "medium", "high", "critical"] as const;
type Severity = (typeof SEVERITY_ORDER)[number];

router.get("/scans", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { targetId, tool, status, severity, from, to } = req.query;

  const conditions = [eq(scanJobsTable.userId, req.user!.sub)];
  if (targetId) conditions.push(eq(scanJobsTable.targetId, targetId as string));
  if (tool) conditions.push(eq(scanJobsTable.tool, tool as any));
  if (status) conditions.push(eq(scanJobsTable.status, status as any));
  if (from) conditions.push(gte(scanJobsTable.createdAt, new Date(from as string)));
  if (to) conditions.push(lte(scanJobsTable.createdAt, new Date(to as string)));

  // Severity filter: only include scans that have at least one finding at or
  // above the requested severity level.
  if (severity && SEVERITY_ORDER.includes(severity as Severity)) {
    const minIndex = SEVERITY_ORDER.indexOf(severity as Severity);
    const matchingSeverities = SEVERITY_ORDER.slice(minIndex) as unknown as Severity[];

    // Find scan job IDs that have findings at or above the requested severity
    const matchingJobIds = await db
      .selectDistinct({ scanJobId: findingsTable.scanJobId })
      .from(findingsTable)
      .where(
        and(
          inArray(findingsTable.severity, matchingSeverities),
          eq(findingsTable.userId, req.user!.sub),
        ),
      );

    const ids = matchingJobIds.map((r) => r.scanJobId).filter(Boolean) as string[];
    if (!ids.length) {
      res.json([]);
      return;
    }
    conditions.push(inArray(scanJobsTable.id, ids));
  }

  const jobs = await db
    .select({
      ...scanJobsTable,
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

  // Legal warning gate: user must have acknowledged the legal warning before any scan
  const users = await db
    .select({ legalWarningAcknowledgedAt: usersTable.legalWarningAcknowledgedAt })
    .from(usersTable)
    .where(eq(usersTable.id, req.user!.sub))
    .limit(1);

  if (!users.length || !users[0].legalWarningAcknowledgedAt) {
    res.status(403).json({
      error: "You must acknowledge the legal warning before creating scans. Call POST /auth/legal-acknowledge.",
      code: "LEGAL_WARNING_REQUIRED",
    });
    return;
  }

  // Load target and verify ownership
  const targets = await db
    .select()
    .from(targetsTable)
    .where(and(eq(targetsTable.id, targetId), eq(targetsTable.userId, req.user!.sub)))
    .limit(1);

  if (!targets.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const target = targets[0];

  if (target.isArchived) {
    res.status(400).json({ error: "Target is archived and cannot be scanned" });
    return;
  }

  // Authorization gate: target must be explicitly authorized
  if (target.authorizationStatus !== "authorized") {
    res.status(403).json({
      error: "Target must be authorized before scanning. Update the target's authorization status.",
    });
    return;
  }

  // Lab-only mode: block public IP targets
  if (LAB_ONLY_MODE && !isPrivateIp(target.address)) {
    res.status(403).json({
      error: "Lab-only mode is enabled. Only private/local IP addresses and hostnames can be scanned.",
    });
    return;
  }

  // Allowed IP ranges check using proper CIDR evaluation
  if (target.allowedIpRanges.length > 0 && !isAddressInRanges(target.address, target.allowedIpRanges)) {
    res.status(403).json({
      error: "Target address is outside the allowed IP ranges defined for this target.",
    });
    return;
  }

  // Rate limit: per user + target
  const allowed = await consumeScanAttempt(req.user!.sub, targetId, res);
  if (!allowed) return;

  // Create the job record
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

  // Enqueue to Redis/Celery worker
  const celeryTaskId = await enqueueScanJob(job.id);
  if (celeryTaskId) {
    await db
      .update(scanJobsTable)
      .set({ workerJobId: celeryTaskId, updatedAt: new Date() })
      .where(eq(scanJobsTable.id, job.id));
  }

  await logAudit(
    { userId: req.user!.sub, targetId, action: "scan_requested", tool },
    req,
  );

  res.status(201).json({ ...job, workerJobId: celeryTaskId });
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
    res.status(400).json({ error: "Cannot cancel a running scan. Wait for it to complete." });
    return;
  }

  await db
    .update(scanJobsTable)
    .set({ status: "cancelled", updatedAt: new Date() })
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
