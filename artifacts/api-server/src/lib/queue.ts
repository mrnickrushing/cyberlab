/**
 * Redis queue client for dispatching scan jobs to the Celery worker.
 * Uses Celery's native message format so the Python worker can consume tasks directly.
 */
import Redis from "ioredis";
import { randomUUID } from "crypto";

const REDIS_URL = process.env.REDIS_URL ?? "redis://localhost:6379";

let redisClient: Redis | null = null;

function getRedis(): Redis {
  if (!redisClient) {
    redisClient = new Redis(REDIS_URL, {
      maxRetriesPerRequest: 3,
      enableOfflineQueue: true,
      retryStrategy: (times) => Math.min(times * 200, 3000),
    });
    redisClient.on("error", (err) => {
      console.error("[queue] Redis error:", err.message);
    });
  }
  return redisClient;
}

/**
 * Enqueue a scan job for the Celery worker using Celery's default JSON message format.
 * Queue name: "celery" (default Celery queue).
 */
export async function enqueueScanJob(jobId: string): Promise<string | null> {
  const taskId = randomUUID();
  const message = {
    id: taskId,
    task: "run_scan",
    args: [jobId],
    kwargs: {},
    retries: 0,
    eta: null,
    expires: null,
    utc: true,
    callbacks: null,
    errbacks: null,
    timelimit: [null, null],
    taskset: null,
    chord: null,
  };

  const celeryMessage = {
    body: Buffer.from(JSON.stringify(message)).toString("base64"),
    "content-encoding": "utf-8",
    "content-type": "application/json",
    headers: {
      lang: "py",
      task: "run_scan",
      id: taskId,
      shadow: null,
      eta: null,
      expires: null,
      group: null,
      group_index: null,
      retries: 0,
      timelimit: [null, null],
      root_id: taskId,
      parent_id: null,
      argsrepr: `('${jobId}',)`,
      kwargsrepr: "{}",
      origin: "cyberlab-api",
    },
    properties: {
      correlation_id: taskId,
      reply_to: randomUUID(),
      delivery_mode: 2,
      delivery_info: {
        exchange: "",
        routing_key: "celery",
      },
      priority: 0,
      body_encoding: "base64",
      delivery_tag: randomUUID(),
    },
  };

  try {
    const redis = getRedis();
    await redis.lpush("celery", JSON.stringify(celeryMessage));
    return taskId;
  } catch (err) {
    console.error("[queue] Failed to enqueue scan job:", err);
    return null;
  }
}

export async function getQueueDepth(): Promise<number> {
  try {
    const redis = getRedis();
    return await redis.llen("celery");
  } catch {
    return -1;
  }
}
