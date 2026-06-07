import {
  pgTable,
  text,
  uuid,
  timestamp,
  boolean,
  jsonb,
} from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { usersTable } from "./users";
import { targetsTable } from "./targets";

export const networkMapsTable = pgTable("network_maps", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => usersTable.id, { onDelete: "cascade" }),
  targetId: uuid("target_id").references(() => targetsTable.id, {
    onDelete: "set null",
  }),
  name: text("name").notNull(),
  subnet: text("subnet").notNull(),
  scannedAt: timestamp("scanned_at", { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const networkHostsTable = pgTable("network_hosts", {
  id: uuid("id").primaryKey().defaultRandom(),
  networkMapId: uuid("network_map_id")
    .notNull()
    .references(() => networkMapsTable.id, { onDelete: "cascade" }),
  ipAddress: text("ip_address").notNull(),
  macAddress: text("mac_address"),
  hostname: text("hostname"),
  vendor: text("vendor"),
  openPorts: jsonb("open_ports").default([]),
  isTrusted: boolean("is_trusted").notNull().default(false),
  isGateway: boolean("is_gateway").notNull().default(false),
  firstSeen: timestamp("first_seen", { withTimezone: true }).notNull().defaultNow(),
  lastSeen: timestamp("last_seen", { withTimezone: true }).notNull().defaultNow(),
});

export const insertNetworkMapSchema = createInsertSchema(networkMapsTable).omit({
  id: true,
  createdAt: true,
  scannedAt: true,
});
export const insertNetworkHostSchema = createInsertSchema(networkHostsTable).omit({
  id: true,
  firstSeen: true,
  lastSeen: true,
});
export const selectNetworkMapSchema = createSelectSchema(networkMapsTable);
export const selectNetworkHostSchema = createSelectSchema(networkHostsTable);

export type NetworkMap = typeof networkMapsTable.$inferSelect;
export type NetworkHost = typeof networkHostsTable.$inferSelect;
