import apn from "@parse/node-apn";
import { db } from "@workspace/db";
import { devicesTable } from "@workspace/db/schema";
import { eq } from "drizzle-orm";
import { logger } from "./logger";

let provider: apn.Provider | null = null;

function getProvider(): apn.Provider | null {
  if (provider) return provider;

  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const privateKey = process.env.APNS_PRIVATE_KEY;

  if (!keyId || !teamId || !privateKey) return null;

  provider = new apn.Provider({
    token: {
      key: Buffer.from(privateKey.replace(/\\n/g, "\n")),
      keyId,
      teamId,
    },
    production: process.env.NODE_ENV === "production",
  });

  return provider;
}

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, unknown>;
  badge?: number;
  sound?: string;
}

export async function pushToUser(userId: string, payload: PushPayload): Promise<void> {
  const p = getProvider();
  if (!p) {
    logger.debug("APNs not configured — skipping push notification");
    return;
  }

  const devices = await db
    .select({ deviceToken: devicesTable.deviceToken })
    .from(devicesTable)
    .where(eq(devicesTable.userId, userId));

  if (!devices.length) return;

  const bundleId = process.env.APNS_BUNDLE_ID ?? "com.cyberlab.mobile";

  for (const { deviceToken } of devices) {
    const note = new apn.Notification();
    note.expiry = Math.floor(Date.now() / 1000) + 3600;
    note.badge = payload.badge;
    note.sound = payload.sound ?? "default";
    note.alert = { title: payload.title, body: payload.body };
    note.topic = bundleId;
    note.payload = { aps: {}, ...payload.data };

    try {
      const result = await p.send(note, deviceToken);
      if (result.failed.length) {
        logger.warn({ token: deviceToken, err: result.failed[0]?.response }, "APNs push failed");
      }
    } catch (err) {
      logger.warn({ err }, "APNs send error");
    }
  }
}

export function isConfigured(): boolean {
  return !!(
    process.env.APNS_KEY_ID &&
    process.env.APNS_TEAM_ID &&
    process.env.APNS_PRIVATE_KEY
  );
}
