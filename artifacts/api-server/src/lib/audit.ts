import { db } from "@workspace/db";
import { auditLogsTable, type InsertAuditLog } from "@workspace/db/schema";
import { type Request } from "express";

export async function logAudit(
  entry: Omit<InsertAuditLog, "ipAddress" | "userAgent">,
  req?: Request,
): Promise<void> {
  try {
    await db.insert(auditLogsTable).values({
      ...entry,
      ipAddress:
        req
          ? (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() ??
            req.socket?.remoteAddress
          : undefined,
      userAgent: req ? (req.headers["user-agent"] ?? undefined) : undefined,
    });
  } catch (err) {
    console.error("Failed to write audit log:", err);
  }
}
