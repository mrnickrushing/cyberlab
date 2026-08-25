import { pgTable, text, uuid, timestamp, boolean, pgEnum, index } from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";

export const scanToolEnum = pgEnum("scan_tool", [
  "nmap",
  "masscan",
  "arp-scan",
  "dns",
  "nikto",
  "nuclei",
  "whatweb",
  "openssl",
  "testssl",
  "gobuster",
  "amass",
  "subfinder",
  "whois",
  "shodan",
  "virustotal",
]);

export const scanProfilesTable = pgTable("scan_profiles", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .references(() => usersTable.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  tool: scanToolEnum("tool").notNull(),
  flags: text("flags").notNull().default(""),
  description: text("description"),
  isDefault: boolean("is_default").notNull().default(false),
  isSystem: boolean("is_system").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  index("scan_profiles_user_id_idx").on(t.userId),
]);

export const insertScanProfileSchema = createInsertSchema(scanProfilesTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export const selectScanProfileSchema = createSelectSchema(scanProfilesTable);

export type InsertScanProfile = typeof scanProfilesTable.$inferInsert;
export type ScanProfile = typeof scanProfilesTable.$inferSelect;
