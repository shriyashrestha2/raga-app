import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditTeamInfo } from "../permissions.js";

// Team Roster / Team Info subsystem. TeamInfo is a singleton row (seeded
// once — see prisma/seed.ts) rather than a per-team table, since this app
// only ever models a single team. Roster/contact fields on individual
// members live on User and are edited via the existing PATCH /users/:id
// (backend/src/routes/users.ts) — this router only owns the team-level row.
export const teamInfoRouter = Router();
teamInfoRouter.use(requireUser);

teamInfoRouter.get("/", async (_req, res) => {
  const teamInfo = await prisma.teamInfo.findFirst();
  if (!teamInfo) return res.status(404).json({ error: "Team info not found" });
  res.json(teamInfo);
});

const updateTeamInfoSchema = z.object({
  teamName: z.string().min(1).optional(),
  season: z.string().min(1).optional(),
  description: z.string().nullable().optional(),
});

teamInfoRouter.patch("/", async (req, res) => {
  if (!canEditTeamInfo(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateTeamInfoSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const existing = await prisma.teamInfo.findFirst();
  if (!existing) return res.status(404).json({ error: "Team info not found" });

  const updated = await prisma.teamInfo.update({
    where: { id: existing.id },
    data: { ...parsed.data, updatedById: req.currentUser!.id },
  });
  res.json(updated);
});
