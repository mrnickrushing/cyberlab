import { pgTable, text, uuid, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";
import { targetsTable } from "./targets";

export const auditActionEnum = pgEnum("audit_action", [
  "scan_requested",
  "target_created",
  "target_updated",
  "target_deleted",
  "target_archived",
  "login",
  "logout",
  "report_generated",
  "note_created",
  "finding_updated",
]);

export const auditLogsTable = pgTable("audit_logs", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").references(() => usersTable.id, {
    onDelete: "set null",
  }),
  targetId: uuid("target_id").references(() => targetsTable.id, {
    onDelete: "set null",
  }),
  action: auditActionEnum("action").notNull(),
  tool: text("tool"),
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  details: text("details"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const insertAuditLogSchema = createInsertSchema(auditLogsTable).omit({
  id: true,
  createdAt: true,
});
export const selectAuditLogSchema = createSelectSchema(auditLogsTable);

export type InsertAuditLog = z.infer<typeof insertAuditLogSchema>;
export type AuditLog = typeof auditLogsTable.$inferSelect;
