import {
  pgTable,
  text,
  uuid,
  timestamp,
  pgEnum,
  real,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";
import { targetsTable } from "./targets";
import { scanJobsTable } from "./scan_jobs";

export const findingStatusEnum = pgEnum("finding_status", [
  "open",
  "fixed",
  "accepted_risk",
  "false_positive",
]);
export const findingSeverityEnum = pgEnum("finding_severity", [
  "critical",
  "high",
  "medium",
  "low",
  "info",
]);

export const findingsTable = pgTable("findings", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => usersTable.id, { onDelete: "cascade" }),
  targetId: uuid("target_id")
    .notNull()
    .references(() => targetsTable.id, { onDelete: "cascade" }),
  scanJobId: uuid("scan_job_id").references(() => scanJobsTable.id, {
    onDelete: "set null",
  }),
  title: text("title").notNull(),
  cveId: text("cve_id"),
  severity: findingSeverityEnum("severity").notNull().default("info"),
  status: findingStatusEnum("status").notNull().default("open"),
  cvssScore: real("cvss_score"),
  owaspCategory: text("owasp_category"),
  description: text("description"),
  remediation: text("remediation"),
  references: text("references").array().notNull().default([]),
  notes: text("notes"),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const findingEventsTable = pgTable("finding_events", {
  id: uuid("id").primaryKey().defaultRandom(),
  findingId: uuid("finding_id")
    .notNull()
    .references(() => findingsTable.id, { onDelete: "cascade" }),
  userId: uuid("user_id").references(() => usersTable.id, {
    onDelete: "set null",
  }),
  previousStatus: findingStatusEnum("previous_status"),
  newStatus: findingStatusEnum("new_status").notNull(),
  note: text("note"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const insertFindingSchema = createInsertSchema(findingsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
  resolvedAt: true,
});
export const selectFindingSchema = createSelectSchema(findingsTable);

export type InsertFinding = z.infer<typeof insertFindingSchema>;
export type Finding = typeof findingsTable.$inferSelect;
export type FindingEvent = typeof findingEventsTable.$inferSelect;
