import {
  pgTable,
  text,
  uuid,
  timestamp,
  unique,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { usersTable } from "./users";

export const devicesTable = pgTable(
  "devices",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => usersTable.id, { onDelete: "cascade" }),
    deviceToken: text("device_token").notNull(),
    platform: text("platform").notNull().default("ios"),
    label: text("label"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [unique("devices_user_token_unique").on(t.userId, t.deviceToken)]
);

export const insertDeviceSchema = createInsertSchema(devicesTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export const selectDeviceSchema = createSelectSchema(devicesTable);

export type InsertDevice = typeof devicesTable.$inferInsert;
export type Device = typeof devicesTable.$inferSelect;
