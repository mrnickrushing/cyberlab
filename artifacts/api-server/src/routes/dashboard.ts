import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  targetsTable,
  scanJobsTable,
  findingsTable,
} from "@workspace/db/schema";
import { eq, and, desc, count, sql } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";

const router: IRouter = Router();

router.get("/dashboard", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const userId = req.user!.sub;

  const [
    targetCountResult,
    activeScanResult,
    findingsBySeverityResult,
    recentScansResult,
  ] = await Promise.all([
    db
      .select({ count: count() })
      .from(targetsTable)
      .where(and(eq(targetsTable.userId, userId), eq(targetsTable.isArchived, false))),

    db
      .select({ count: count() })
      .from(scanJobsTable)
      .where(and(eq(scanJobsTable.userId, userId), eq(scanJobsTable.status, "running"))),

    db
      .select({
        severity: findingsTable.severity,
        count: count(),
      })
      .from(findingsTable)
      .where(and(eq(findingsTable.userId, userId), eq(findingsTable.status, "open")))
      .groupBy(findingsTable.severity),

    db
      .select({
        job: scanJobsTable,
        targetName: targetsTable.name,
        targetAddress: targetsTable.address,
      })
      .from(scanJobsTable)
      .leftJoin(targetsTable, eq(scanJobsTable.targetId, targetsTable.id))
      .where(eq(scanJobsTable.userId, userId))
      .orderBy(desc(scanJobsTable.createdAt))
      .limit(5),
  ]);

  const findingCounts: Record<string, number> = {};
  for (const row of findingsBySeverityResult) {
    findingCounts[row.severity] = Number(row.count);
  }

  const criticalCount = findingCounts["critical"] ?? 0;
  const highCount = findingCounts["high"] ?? 0;
  const totalOpenFindings = Object.values(findingCounts).reduce((a, b) => a + b, 0);

  const maxScore = 100;
  const deduction = Math.min(criticalCount * 20 + highCount * 10, maxScore);
  const securityScore = Math.max(0, maxScore - deduction);

  res.json({
    securityScore,
    targetCount: Number(targetCountResult[0]?.count ?? 0),
    activeScans: Number(activeScanResult[0]?.count ?? 0),
    openFindings: totalOpenFindings,
    findingsBySeverity: findingCounts,
    recentScans: recentScansResult,
    labHealth: {
      apiReachable: true,
      workerQueueDepth: 0,
    },
  });
});

export default router;
