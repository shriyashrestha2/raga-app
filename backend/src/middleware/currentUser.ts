import type { NextFunction, Request, Response } from "express";
import { prisma } from "../prisma.js";
import type { RoleName } from "../permissions.js";

export interface CurrentUser {
  id: string;
  name: string;
  role: RoleName;
}

/**
 * The one function identity resolution goes through. There's no real login
 * yet (see README's documented follow-up) — the client identifies itself via
 * the `x-user-id` header (the server-trusted successor to the old spoofable
 * `?role=` query param), and the server looks up that user's real role from
 * the DB rather than trusting any client-sent role string. Swapping in real
 * auth later (verifying a session/JWT instead) only means replacing this
 * function's body — nothing downstream (permissions.ts, route handlers)
 * changes, since they only ever consume the resolved `CurrentUser`.
 */
export async function resolveCurrentUser(req: Request): Promise<CurrentUser | null> {
  const userId = req.header("x-user-id");
  if (!userId) return null;
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return null;
  return { id: user.id, name: user.name, role: user.role as RoleName };
}

export async function attachCurrentUser(req: Request, _res: Response, next: NextFunction) {
  req.currentUser = (await resolveCurrentUser(req)) ?? undefined;
  next();
}

export function requireUser(req: Request, res: Response, next: NextFunction) {
  if (!req.currentUser) {
    return res.status(401).json({ error: "Missing or invalid x-user-id header" });
  }
  next();
}

export function requireRole(...roles: RoleName[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.currentUser) {
      return res.status(401).json({ error: "Missing or invalid x-user-id header" });
    }
    if (!roles.includes(req.currentUser.role)) {
      return res.status(403).json({ error: "You don't have access to this." });
    }
    next();
  };
}
