import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import { auditLogsTable, usersTable, targetsTable } from "@workspace/db/schema";
import { eq, and, desc, gte, lte } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";

const router: IRouter = Router();

router.get("/audit", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { targetId, action, from, to, limit = "50", offset = "0" } = req.query;

  const conditions = [eq(auditLogsTable.userId, req.user!.sub)];
  if (targetId) conditions.push(eq(auditLogsTable.targetId, targetId as string));
  if (action) conditions.push(eq(auditLogsTable.action, action as any));
  if (from) conditions.push(gte(auditLogsTable.createdAt, new Date(from as string)));
  if (to) conditions.push(lte(auditLogsTable.createdAt, new Date(to as string)));

  const logs = await db
    .select({
      log: auditLogsTable,
      targetName: targetsTable.name,
      targetAddress: targetsTable.address,
    })
    .from(auditLogsTable)
    .leftJoin(targetsTable, eq(auditLogsTable.targetId, targetsTable.id))
    .where(and(...conditions))
    .orderBy(desc(auditLogsTable.createdAt))
    .limit(Math.min(Number(limit), 200))
    .offset(Number(offset));

  res.json(logs);
});

export default router;
