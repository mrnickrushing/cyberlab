import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import { schedulesTable, targetsTable } from "@workspace/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { z } from "zod";

const router: IRouter = Router();

const VALID_TOOLS = [
  "nmap", "nuclei", "nikto", "whatweb", "testssl", "openssl",
  "gobuster", "amass", "subfinder", "dns", "whois",
  "shodan", "virustotal", "abuseipdb", "ipinfo", "hibp",
];

const VALID_CRONS = [
  { label: "Every hour",         value: "0 * * * *"   },
  { label: "Every 6 hours",      value: "0 */6 * * *" },
  { label: "Every 12 hours",     value: "0 */12 * * *"},
  { label: "Daily at midnight",  value: "0 0 * * *"   },
  { label: "Every Monday 2am",   value: "0 2 * * 1"   },
  { label: "Every Sunday 3am",   value: "0 3 * * 0"   },
];

const createScheduleSchema = z.object({
  targetId: z.string().uuid(),
  tool: z.enum(VALID_TOOLS as [string, ...string[]]),
  flags: z.string().max(500).optional().default(""),
  cronExpression: z.string().min(9).max(100),
  label: z.string().max(100).optional(),
});

const updateScheduleSchema = z.object({
  enabled: z.boolean().optional(),
  cronExpression: z.string().min(9).max(100).optional(),
  label: z.string().max(100).optional(),
  flags: z.string().max(500).optional(),
});

// GET /schedules
router.get("/schedules", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const rows = await db
    .select({
      id: schedulesTable.id,
      tool: schedulesTable.tool,
      flags: schedulesTable.flags,
      cronExpression: schedulesTable.cronExpression,
      label: schedulesTable.label,
      enabled: schedulesTable.enabled,
      lastRunAt: schedulesTable.lastRunAt,
      nextRunAt: schedulesTable.nextRunAt,
      createdAt: schedulesTable.createdAt,
      targetId: schedulesTable.targetId,
      targetName: targetsTable.name,
      targetAddress: targetsTable.address,
    })
    .from(schedulesTable)
    .innerJoin(targetsTable, eq(schedulesTable.targetId, targetsTable.id))
    .where(eq(schedulesTable.userId, req.user!.sub))
    .orderBy(desc(schedulesTable.createdAt));

  res.json(rows);
});

// GET /schedules/presets — return valid cron presets
router.get("/schedules/presets", authenticate, (_req, res) => {
  res.json({ tools: VALID_TOOLS, cronPresets: VALID_CRONS });
});

// POST /schedules
router.post("/schedules", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createScheduleSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const { targetId, tool, flags, cronExpression, label } = parsed.data;
  const userId = req.user!.sub;

  // Verify target belongs to user
  const [target] = await db
    .select({ id: targetsTable.id })
    .from(targetsTable)
    .where(and(eq(targetsTable.id, targetId), eq(targetsTable.userId, userId)));

  if (!target) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const [schedule] = await db
    .insert(schedulesTable)
    .values({
      userId,
      targetId,
      tool,
      flags: { flags },
      cronExpression,
      label,
      enabled: true,
    })
    .returning();

  res.status(201).json(schedule);
});

// PATCH /schedules/:id
router.patch("/schedules/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = updateScheduleSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const { id } = req.params;
  const updates: Record<string, unknown> = { updatedAt: new Date() };
  if (parsed.data.enabled !== undefined) updates.enabled = parsed.data.enabled;
  if (parsed.data.cronExpression) updates.cronExpression = parsed.data.cronExpression;
  if (parsed.data.label !== undefined) updates.label = parsed.data.label;
  if (parsed.data.flags !== undefined) updates.flags = { flags: parsed.data.flags };

  const [updated] = await db
    .update(schedulesTable)
    .set(updates)
    .where(and(eq(schedulesTable.id, id), eq(schedulesTable.userId, req.user!.sub)))
    .returning();

  if (!updated) {
    res.status(404).json({ error: "Schedule not found" });
    return;
  }

  res.json(updated);
});

// DELETE /schedules/:id
router.delete("/schedules/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(schedulesTable)
    .where(and(eq(schedulesTable.id, req.params.id), eq(schedulesTable.userId, req.user!.sub)))
    .returning({ id: schedulesTable.id });

  if (!deleted) {
    res.status(404).json({ error: "Schedule not found" });
    return;
  }

  res.status(200).json({ ok: true });
});

// POST /notify/internal — called by the worker after scan completion
// Protected by a shared internal secret rather than user JWT
router.post("/notify/internal", async (req, res): Promise<void> => {
  const secret = process.env.INTERNAL_NOTIFY_SECRET;
  if (!secret || req.headers["x-internal-secret"] !== secret) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { userId, jobId, tool, address, status, criticalCount } = req.body as {
    userId: string;
    jobId: string;
    tool: string;
    address: string;
    status: "completed" | "failed";
    criticalCount?: number;
  };

  const { pushToUser } = await import("../lib/notifications.js");

  if (status === "completed") {
    const hasCritical = (criticalCount ?? 0) > 0;
    await pushToUser(userId, {
      title: hasCritical ? "⚠️ Critical Findings Detected" : "✅ Scan Complete",
      body: hasCritical
        ? `${tool} on ${address} — ${criticalCount} critical finding${criticalCount! > 1 ? "s" : ""} found`
        : `${tool} on ${address} finished successfully`,
      data: { jobId, tool, address },
      badge: hasCritical ? 1 : undefined,
    });
  } else {
    await pushToUser(userId, {
      title: "❌ Scan Failed",
      body: `${tool} on ${address} encountered an error`,
      data: { jobId, tool, address },
    });
  }

  res.json({ ok: true });
});

export default router;
