import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditTeamInfo, canManageRoles } from "../permissions.js";

export const usersRouter = Router();

// Dev-only helper: since there's no real login yet, the client asks for "the
// list of demo users" to pick an identity from before it has one. Must stay
// public — it's the bootstrap list, requested before any x-user-id exists.
usersRouter.get("/", async (_req, res) => {
  const users = await prisma.user.findMany({ orderBy: { name: "asc" } });
  res.json(users);
});

const updateRosterSchema = z.object({
  email: z.string().email().nullable().optional(),
  phone: z.string().nullable().optional(),
  year: z.string().nullable().optional(),
  major: z.string().nullable().optional(),
  bio: z.string().nullable().optional(),
  emergencyContactName: z.string().nullable().optional(),
  emergencyContactPhone: z.string().nullable().optional(),
});

// Roster/contact fields. Deliberately excludes `role` — see PATCH /:id/role
// below, which is the only endpoint that can change a member's role.
usersRouter.patch<{ id: string }>("/:id", requireUser, async (req, res) => {
  if (!canEditTeamInfo(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateRosterSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const user = await prisma.user.update({ where: { id: req.params.id }, data: parsed.data });
  res.json(user);
});

const updateRoleSchema = z.object({
  role: z.enum(["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "DANCER", "NEWBIE"]),
});

// Captain-only: assigning/changing which role a member holds.
usersRouter.patch<{ id: string }>("/:id/role", requireUser, async (req, res) => {
  if (!canManageRoles(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateRoleSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const user = await prisma.user.update({ where: { id: req.params.id }, data: { role: parsed.data.role } });
  res.json(user);
});
