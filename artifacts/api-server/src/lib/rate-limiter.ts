import { RateLimiterMemory } from "rate-limiter-flexible";
import { Request, Response } from "express";

const authLimiter = new RateLimiterMemory({
  points: 10,
  duration: 60,
  blockDuration: 120,
});

const scanLimiter = new RateLimiterMemory({
  points: 20,
  duration: 60,
});

export async function consumeAuthAttempt(req: Request, res: Response): Promise<boolean> {
  const key = (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() ?? req.socket?.remoteAddress ?? "unknown";
  try {
    await authLimiter.consume(key);
    return true;
  } catch {
    res.status(429).json({ error: "Too many login attempts. Try again in 2 minutes." });
    return false;
  }
}

export async function consumeScanAttempt(userId: string, targetId: string, res: Response): Promise<boolean> {
  const key = `${userId}:${targetId}`;
  try {
    await scanLimiter.consume(key);
    return true;
  } catch {
    res.status(429).json({ error: "Scan rate limit exceeded for this target. Please wait before launching another scan." });
    return false;
  }
}
