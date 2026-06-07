import {
  pgTable,
  text,
  uuid,
  timestamp,
  boolean,
  pgEnum,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";

export const targetTypeEnum = pgEnum("target_type", [
  "ip",
  "domain",
  "subnet",
  "webapp",
]);
export const authStatusEnum = pgEnum("auth_status", [
  "authorized",
  "unauthorized",
  "pending",
]);
export const riskLevelEnum = pgEnum("risk_level", [
  "critical",
  "high",
  "medium",
  "low",
  "info",
]);

export const targetsTable = pgTable("targets", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => usersTable.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  type: targetTypeEnum("type").notNull(),
  address: text("address").notNull(),
  owner: text("owner"),
  authorizationStatus: authStatusEnum("authorization_status")
    .notNull()
    .default("pending"),
  riskLevel: riskLevelEnum("risk_level").notNull().default("info"),
  tags: text("tags").array().notNull().default([]),
  scopeNotes: text("scope_notes"),
  allowedIpRanges: text("allowed_ip_ranges").array().notNull().default([]),
  isArchived: boolean("is_archived").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const insertTargetSchema = createInsertSchema(targetsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export const selectTargetSchema = createSelectSchema(targetsTable);

export type InsertTarget = typeof targetsTable.$inferInsert;
export type Target = typeof targetsTable.$inferSelect;
