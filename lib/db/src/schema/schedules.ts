import {
  pgTable,
  text,
  uuid,
  timestamp,
  boolean,
  jsonb,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { usersTable } from "./users";
import { targetsTable } from "./targets";

export const schedulesTable = pgTable("schedules", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => usersTable.id, { onDelete: "cascade" }),
  targetId: uuid("target_id")
    .notNull()
    .references(() => targetsTable.id, { onDelete: "cascade" }),
  tool: text("tool").notNull(),
  flags: jsonb("flags").notNull().default({}),
  cronExpression: text("cron_expression").notNull(),
  label: text("label"),
  enabled: boolean("enabled").notNull().default(true),
  lastRunAt: timestamp("last_run_at", { withTimezone: true }),
  nextRunAt: timestamp("next_run_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const insertScheduleSchema = createInsertSchema(schedulesTable).omit({
  id: true,
  lastRunAt: true,
  nextRunAt: true,
  createdAt: true,
  updatedAt: true,
});
export const selectScheduleSchema = createSelectSchema(schedulesTable);

export type InsertSchedule = typeof schedulesTable.$inferInsert;
export type Schedule = typeof schedulesTable.$inferSelect;
