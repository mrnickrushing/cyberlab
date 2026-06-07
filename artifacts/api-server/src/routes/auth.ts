import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import { usersTable } from "@workspace/db/schema";
import { eq } from "drizzle-orm";
import {
  signToken,
  signRefreshToken,
  verifyToken,
  hashPassword,
  verifyPassword,
  extractBearerToken,
} from "../lib/auth";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { logAudit } from "../lib/audit";
import { consumeAuthAttempt } from "../lib/rate-limiter";
import { z } from "zod/v4";

const router: IRouter = Router();

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

const registerSchema = z.object({
  username: z.string().min(3).max(50),
  email: z.string().email(),
  password: z.string().min(8),
});

router.post("/auth/register", async (req, res): Promise<void> => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }
  const { username, email, password } = parsed.data;

  const existing = await db
    .select({ id: usersTable.id })
    .from(usersTable)
    .where(eq(usersTable.username, username))
    .limit(1);

  if (existing.length) {
    res.status(409).json({ error: "Username already taken" });
    return;
  }

  const passwordHash = await hashPassword(password);
  const [user] = await db
    .insert(usersTable)
    .values({ username, email, passwordHash })
    .returning({ id: usersTable.id, username: usersTable.username, email: usersTable.email });

  await logAudit({ userId: user.id, action: "login", details: "User registered" }, req);

  const token = signToken({ sub: user.id, username: user.username });
  const refreshToken = signRefreshToken({ sub: user.id, username: user.username });
  res.status(201).json({ token, refreshToken, user });
});

router.post("/auth/login", async (req, res): Promise<void> => {
  const allowed = await consumeAuthAttempt(req, res);
  if (!allowed) return;

  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input" });
    return;
  }
  const { username, password } = parsed.data;

  const users = await db
    .select()
    .from(usersTable)
    .where(eq(usersTable.username, username))
    .limit(1);

  if (!users.length || !users[0].isActive) {
    res.status(401).json({ error: "Invalid credentials" });
    return;
  }

  const user = users[0];
  const valid = await verifyPassword(password, user.passwordHash);
  if (!valid) {
    res.status(401).json({ error: "Invalid credentials" });
    return;
  }

  await logAudit({ userId: user.id, action: "login" }, req);

  const token = signToken({ sub: user.id, username: user.username });
  const refreshToken = signRefreshToken({ sub: user.id, username: user.username });
  res.json({
    token,
    refreshToken,
    user: { id: user.id, username: user.username, email: user.email },
  });
});

router.post("/auth/refresh", async (req, res): Promise<void> => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(400).json({ error: "refreshToken is required" });
    return;
  }
  try {
    const payload = verifyToken(refreshToken);
    const token = signToken({ sub: payload.sub, username: payload.username });
    res.json({ token });
  } catch {
    res.status(401).json({ error: "Invalid or expired refresh token" });
  }
});

router.get("/auth/me", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const users = await db
    .select({
      id: usersTable.id,
      username: usersTable.username,
      email: usersTable.email,
      createdAt: usersTable.createdAt,
    })
    .from(usersTable)
    .where(eq(usersTable.id, req.user!.sub))
    .limit(1);

  if (!users.length) {
    res.status(404).json({ error: "User not found" });
    return;
  }
  res.json(users[0]);
});

router.post("/auth/logout", authenticate, async (req: AuthRequest, res): Promise<void> => {
  await logAudit({ userId: req.user!.sub, action: "logout" }, req);
  res.json({ message: "Logged out" });
});

export default router;
