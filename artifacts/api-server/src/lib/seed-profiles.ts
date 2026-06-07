/**
 * Seeds default system scan profiles into the database.
 * Run once on startup if no system profiles exist.
 */
import { db } from "@workspace/db";
import { scanProfilesTable } from "@workspace/db/schema";
import { eq, count } from "drizzle-orm";

const DEFAULT_PROFILES = [
  {
    name: "Quick Scan",
    tool: "nmap" as const,
    flags: "-T4 -F",
    description: "Fast scan of top 100 ports",
    isDefault: true,
    isSystem: true,
  },
  {
    name: "Full TCP Scan",
    tool: "nmap" as const,
    flags: "-T4 -p-",
    description: "Scan all 65535 TCP ports",
    isDefault: false,
    isSystem: true,
  },
  {
    name: "Service & Version Detection",
    tool: "nmap" as const,
    flags: "-T4 -sV -sC -p-",
    description: "Full port scan with service/version detection and default scripts",
    isDefault: false,
    isSystem: true,
  },
  {
    name: "Stealth SYN Scan",
    tool: "nmap" as const,
    flags: "-T4 -sS -p-",
    description: "SYN stealth scan (requires root inside worker container)",
    isDefault: false,
    isSystem: true,
  },
  {
    name: "Top 1000 UDP",
    tool: "nmap" as const,
    flags: "-sU --top-ports 100 -T4",
    description: "UDP scan of top 100 ports",
    isDefault: false,
    isSystem: true,
  },
  {
    name: "Slow & Careful",
    tool: "nmap" as const,
    flags: "-T1 -sV -p-",
    description: "Timing T1 — evades basic IDS, thorough results",
    isDefault: false,
    isSystem: true,
  },
  {
    name: "Local Network Discovery",
    tool: "arp-scan" as const,
    flags: "localnet",
    description: "Discover all live hosts on the local subnet via ARP",
    isDefault: true,
    isSystem: true,
  },
];

export async function seedDefaultProfiles(): Promise<void> {
  const existing = await db
    .select({ count: count() })
    .from(scanProfilesTable)
    .where(eq(scanProfilesTable.isSystem, true));

  if (Number(existing[0].count) > 0) return;

  await db.insert(scanProfilesTable).values(
    DEFAULT_PROFILES.map((p) => ({ ...p, userId: null })),
  );
}
