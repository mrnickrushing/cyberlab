import { Request, Response, NextFunction } from "express";
import { verifyToken, extractBearerToken, type JwtPayload } from "../lib/auth";

export interface AuthRequest extends Request {
  user?: JwtPayload;
}

export function authenticate(
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): void {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    res.status(401).json({ error: "Missing authorization token" });
    return;
  }
  try {
    req.user = verifyToken(token);
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}
