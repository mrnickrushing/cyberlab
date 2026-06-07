import {
  pgTable,
  text,
  uuid,
  timestamp,
  jsonb,
  pgEnum,
  integer,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";
import { targetsTable } from "./targets";
import { scanProfilesTable, scanToolEnum } from "./scan_profiles";

export const jobStatusEnum = pgEnum("job_status", [
  "pending",
  "running",
  "completed",
  "failed",
  "cancelled",
]);

export const scanJobsTable = pgTable("scan_jobs", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => usersTable.id, { onDelete: "cascade" }),
  targetId: uuid("target_id")
    .notNull()
    .references(() => targetsTable.id, { onDelete: "cascade" }),
  profileId: uuid("profile_id").references(() => scanProfilesTable.id, {
    onDelete: "set null",
  }),
  tool: scanToolEnum("tool").notNull(),
  flags: text("flags").notNull().default(""),
  status: jobStatusEnum("status").notNull().default("pending"),
  progress: integer("progress").notNull().default(0),
  workerJobId: text("worker_job_id"),
  startedAt: timestamp("started_at", { withTimezone: true }),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  errorMessage: text("error_message"),
  meta: jsonb("meta").default({}),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const scanResultsTable = pgTable("scan_results", {
  id: uuid("id").primaryKey().defaultRandom(),
  scanJobId: uuid("scan_job_id")
    .notNull()
    .references(() => scanJobsTable.id, { onDelete: "cascade" }),
  rawOutput: text("raw_output"),
  parsedData: jsonb("parsed_data").default({}),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const insertScanJobSchema = createInsertSchema(scanJobsTable).omit({
  id: true,
  createdAt: true,
  startedAt: true,
  completedAt: true,
});
export const selectScanJobSchema = createSelectSchema(scanJobsTable);
export const selectScanResultSchema = createSelectSchema(scanResultsTable);

export type InsertScanJob = typeof scanJobsTable.$inferInsert;
export type ScanJob = typeof scanJobsTable.$inferSelect;
export type ScanResult = typeof scanResultsTable.$inferSelect;
