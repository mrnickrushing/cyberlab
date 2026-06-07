import { Response, NextFunction } from "express";
import { db } from "@workspace/db";
import { targetsTable } from "@workspace/db/schema";
import { eq, and } from "drizzle-orm";
import { type AuthRequest } from "./authenticate";
import { isPrivateIp } from "../lib/ip-utils";

const LAB_ONLY_MODE = process.env.LAB_ONLY_MODE === "true";

export async function authorizeTarget(
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const targetId = req.params.targetId ?? req.body?.targetId;
  if (!targetId) {
    res.status(400).json({ error: "targetId is required" });
    return;
  }

  const target = await db
    .select()
    .from(targetsTable)
    .where(
      and(
        eq(targetsTable.id, targetId),
        eq(targetsTable.userId, req.user!.sub),
      ),
    )
    .limit(1);

  if (!target.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const t = target[0];

  if (t.isArchived) {
    res.status(400).json({ error: "Target is archived" });
    return;
  }

  if (t.authorizationStatus !== "authorized") {
    res
      .status(403)
      .json({
        error:
          "Target is not authorized. Mark it as authorized before scanning.",
      });
    return;
  }

  if (LAB_ONLY_MODE && !isPrivateIp(t.address)) {
    res
      .status(403)
      .json({
        error:
          "Lab-only mode is enabled. Public IP addresses cannot be scanned.",
      });
    return;
  }

  (req as AuthRequest & { target: typeof t }).target = t;
  next();
}
