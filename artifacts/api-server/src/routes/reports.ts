import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import {
  targetsTable,
  findingsTable,
  scanJobsTable,
  scanResultsTable,
} from "@workspace/db/schema";
import { eq, and, desc, count, sql } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";

const router: IRouter = Router();

const SEVERITY_WEIGHTS: Record<string, number> = {
  critical: 25,
  high: 15,
  medium: 10,
  low: 5,
  info: 1,
};

function calcRiskScore(findings: { severity: string; status: string }[]): number {
  const deduction = findings
    .filter((f) => f.status === "open")
    .reduce((acc, f) => acc + (SEVERITY_WEIGHTS[f.severity] ?? 0), 0);
  return Math.max(0, 100 - deduction);
}

function riskLabel(score: number): string {
  if (score >= 80) return "Low Risk";
  if (score >= 60) return "Medium Risk";
  if (score >= 40) return "High Risk";
  return "Critical Risk";
}

// GET /reports — list all authorized targets with their report summary
router.get("/reports", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const targets = await db
    .select()
    .from(targetsTable)
    .where(
      and(
        eq(targetsTable.userId, req.user!.sub),
        eq(targetsTable.isArchived, false)
      )
    )
    .orderBy(desc(targetsTable.createdAt));

  const summaries = await Promise.all(
    targets.map(async (target) => {
      const findings = await db
        .select({ severity: findingsTable.severity, status: findingsTable.status })
        .from(findingsTable)
        .where(eq(findingsTable.targetId, target.id));

      const scanCount = await db
        .select({ count: count() })
        .from(scanJobsTable)
        .where(
          and(
            eq(scanJobsTable.targetId, target.id),
            eq(scanJobsTable.userId, req.user!.sub)
          )
        );

      const riskScore = calcRiskScore(findings);
      const bySeverity = { critical: 0, high: 0, medium: 0, low: 0, info: 0 };
      for (const f of findings) {
        if (f.status === "open") {
          bySeverity[f.severity as keyof typeof bySeverity] =
            (bySeverity[f.severity as keyof typeof bySeverity] ?? 0) + 1;
        }
      }

      return {
        targetId: target.id,
        targetName: target.name,
        targetAddress: target.address,
        targetType: target.type,
        riskScore,
        riskLabel: riskLabel(riskScore),
        totalFindings: findings.filter((f) => f.status === "open").length,
        bySeverity,
        totalScans: scanCount[0]?.count ?? 0,
        generatedAt: new Date().toISOString(),
      };
    })
  );

  res.json(summaries);
});

// GET /reports/:targetId — full report JSON
router.get("/reports/:targetId", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [target] = await db
    .select()
    .from(targetsTable)
    .where(
      and(
        eq(targetsTable.id, req.params.targetId),
        eq(targetsTable.userId, req.user!.sub)
      )
    )
    .limit(1);

  if (!target) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const findings = await db
    .select()
    .from(findingsTable)
    .where(eq(findingsTable.targetId, target.id))
    .orderBy(
      sql`CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END`,
      desc(findingsTable.createdAt)
    );

  const scans = await db
    .select({
      id: scanJobsTable.id,
      tool: scanJobsTable.tool,
      status: scanJobsTable.status,
      createdAt: scanJobsTable.createdAt,
      completedAt: scanJobsTable.completedAt,
    })
    .from(scanJobsTable)
    .where(
      and(
        eq(scanJobsTable.targetId, target.id),
        eq(scanJobsTable.userId, req.user!.sub)
      )
    )
    .orderBy(desc(scanJobsTable.createdAt))
    .limit(20);

  const riskScore = calcRiskScore(findings);
  const openFindings = findings.filter((f) => f.status === "open");
  const bySeverity = { critical: 0, high: 0, medium: 0, low: 0, info: 0 };
  for (const f of openFindings) {
    bySeverity[f.severity as keyof typeof bySeverity] =
      (bySeverity[f.severity as keyof typeof bySeverity] ?? 0) + 1;
  }

  // Unique remediation templates from open findings
  const remediations = [
    ...new Map(
      openFindings
        .filter((f) => f.remediation)
        .map((f) => [f.title, { title: f.title, severity: f.severity, remediation: f.remediation }])
    ).values(),
  ].slice(0, 20);

  res.json({
    generatedAt: new Date().toISOString(),
    target: {
      id: target.id,
      name: target.name,
      address: target.address,
      type: target.type,
      authorizationStatus: target.authorizationStatus,
      riskLevel: target.riskLevel,
      owner: target.owner,
    },
    riskScore,
    riskLabel: riskLabel(riskScore),
    summary: {
      totalFindings: findings.length,
      openFindings: openFindings.length,
      bySeverity,
      totalScans: scans.length,
      toolsUsed: [...new Set(scans.map((s) => s.tool))],
    },
    findings: findings.map((f) => ({
      id: f.id,
      title: f.title,
      severity: f.severity,
      status: f.status,
      cveId: f.cveId,
      cvssScore: f.cvssScore,
      description: f.description,
      remediation: f.remediation,
      createdAt: f.createdAt,
    })),
    scans,
    remediations,
  });
});

export default router;
