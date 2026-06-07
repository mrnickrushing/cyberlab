import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  networkMapsTable,
  networkHostsTable,
  scanJobsTable,
  targetsTable,
} from "@workspace/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { enqueueScanJob } from "../lib/queue";
import { z } from "zod";

const router: IRouter = Router();

const createMapSchema = z.object({
  name: z.string().min(1).max(200),
  subnet: z.string().min(1),
  targetId: z.string().uuid().optional(),
});

const createHostSchema = z.object({
  networkMapId: z.string().uuid(),
  ipAddress: z.string().min(1),
  macAddress: z.string().optional(),
  hostname: z.string().optional(),
  vendor: z.string().optional(),
  openPorts: z.array(z.any()).default([]),
  isTrusted: z.boolean().default(false),
  isGateway: z.boolean().default(false),
});

router.get("/networks", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select()
    .from(networkMapsTable)
    .where(eq(networkMapsTable.userId, req.user!.sub))
    .orderBy(desc(networkMapsTable.createdAt));
  res.json(maps);
});

router.post("/networks", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createMapSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }
  const [map] = await db
    .insert(networkMapsTable)
    .values({ ...parsed.data, userId: req.user!.sub })
    .returning();
  res.status(201).json(map);
});

router.get("/networks/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select()
    .from(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.id), eq(networkMapsTable.userId, req.user!.sub)))
    .limit(1);
  if (!maps.length) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  const hosts = await db
    .select()
    .from(networkHostsTable)
    .where(eq(networkHostsTable.networkMapId, req.params.id))
    .orderBy(networkHostsTable.ipAddress);
  res.json({ ...maps[0], hosts });
});

router.delete("/networks/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.id), eq(networkMapsTable.userId, req.user!.sub)))
    .returning({ id: networkMapsTable.id });
  if (!deleted) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  res.status(204).send();
});

router.get("/networks/:id/hosts", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select({ id: networkMapsTable.id })
    .from(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.id), eq(networkMapsTable.userId, req.user!.sub)))
    .limit(1);
  if (!maps.length) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  const hosts = await db
    .select()
    .from(networkHostsTable)
    .where(eq(networkHostsTable.networkMapId, req.params.id))
    .orderBy(networkHostsTable.ipAddress);
  res.json(hosts);
});

router.post("/networks/:id/hosts", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select({ id: networkMapsTable.id })
    .from(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.id), eq(networkMapsTable.userId, req.user!.sub)))
    .limit(1);
  if (!maps.length) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  const parsed = createHostSchema.safeParse({ ...req.body, networkMapId: req.params.id });
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }
  const [host] = await db
    .insert(networkHostsTable)
    .values(parsed.data)
    .returning();
  res.status(201).json(host);
});

router.patch("/networks/:mapId/hosts/:hostId", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select({ id: networkMapsTable.id })
    .from(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.mapId), eq(networkMapsTable.userId, req.user!.sub)))
    .limit(1);
  if (!maps.length) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  const updateSchema = z.object({
    isTrusted: z.boolean().optional(),
    isGateway: z.boolean().optional(),
    hostname: z.string().optional(),
    vendor: z.string().optional(),
  });
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input" });
    return;
  }
  const [updated] = await db
    .update(networkHostsTable)
    .set({ ...parsed.data, lastSeen: new Date() })
    .where(and(eq(networkHostsTable.id, req.params.hostId), eq(networkHostsTable.networkMapId, req.params.mapId)))
    .returning();
  if (!updated) {
    res.status(404).json({ error: "Host not found" });
    return;
  }
  res.json(updated);
});

// POST /networks/:id/discover — auto-create a subnet target + enqueue arp-scan
router.post("/networks/:id/discover", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const maps = await db
    .select()
    .from(networkMapsTable)
    .where(and(eq(networkMapsTable.id, req.params.id), eq(networkMapsTable.userId, req.user!.sub)))
    .limit(1);
  if (!maps.length) {
    res.status(404).json({ error: "Network map not found" });
    return;
  }
  const map = maps[0];

  let targetId = map.targetId ?? null;

  if (!targetId) {
    const [target] = await db
      .insert(targetsTable)
      .values({
        userId: req.user!.sub,
        name: `${map.name} – ${map.subnet}`,
        type: "subnet",
        address: map.subnet,
        authorizationStatus: "authorized",
        riskLevel: "info",
        isArchived: false,
        tags: [],
      })
      .returning({ id: targetsTable.id });
    targetId = target.id;
    await db
      .update(networkMapsTable)
      .set({ targetId })
      .where(eq(networkMapsTable.id, map.id));
  }

  const [job] = await db
    .insert(scanJobsTable)
    .values({
      userId: req.user!.sub,
      targetId,
      tool: "arp-scan",
      flags: "",
      status: "pending",
      meta: { networkMapId: map.id },
    })
    .returning();

  const celeryTaskId = await enqueueScanJob(job.id);
  if (celeryTaskId) {
    await db
      .update(scanJobsTable)
      .set({ workerJobId: celeryTaskId })
      .where(eq(scanJobsTable.id, job.id));
  }

  res.status(201).json({ scanJobId: job.id });
});

export default router;
