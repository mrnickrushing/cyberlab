import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import { devicesTable } from "@workspace/db/schema";
import { eq, and } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { z } from "zod";

const router: IRouter = Router();

const registerSchema = z.object({
  deviceToken: z.string().min(32).max(200),
  label: z.string().max(100).optional(),
});

// POST /devices/register
router.post("/devices/register", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const { deviceToken, label } = parsed.data;
  const userId = req.user!.sub;

  await db
    .insert(devicesTable)
    .values({ userId, deviceToken, label, platform: "ios" })
    .onConflictDoUpdate({
      target: [devicesTable.userId, devicesTable.deviceToken],
      set: { label, updatedAt: new Date() },
    });

  res.status(200).json({ ok: true });
});

// DELETE /devices/unregister
router.delete("/devices/unregister", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { deviceToken } = req.body as { deviceToken?: string };
  if (!deviceToken) {
    res.status(400).json({ error: "deviceToken required" });
    return;
  }

  await db
    .delete(devicesTable)
    .where(
      and(
        eq(devicesTable.userId, req.user!.sub),
        eq(devicesTable.deviceToken, deviceToken)
      )
    );

  res.status(200).json({ ok: true });
});

// GET /devices — list registered devices for current user
router.get("/devices", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const devices = await db
    .select({
      id: devicesTable.id,
      platform: devicesTable.platform,
      label: devicesTable.label,
      createdAt: devicesTable.createdAt,
    })
    .from(devicesTable)
    .where(eq(devicesTable.userId, req.user!.sub));

  res.json(devices);
});

export default router;
