import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canManageFineSchedule, isBoardRole } from "../permissions.js";

export const fineScheduleRouter = Router();
fineScheduleRouter.use(requireUser);

// The schedule lives inside the now board-only Fines tab, so viewing it is
// board-gated too — only editing has its own (narrower) capability.
fineScheduleRouter.get("/", async (req, res) => {
  if (!isBoardRole(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const items = await prisma.fineScheduleItem.findMany({ orderBy: { order: "asc" } });
  res.json(items);
});

// Exactly one of amountCents (fixed) / description (variable-rule text) must
// be present — mirrors the Fines Tracker spec's four variable-amount
// offenses, which store a plain-text rule instead of a dollar figure.
const bodySchema = z
  .object({
    offense: z.string().min(1),
    amountCents: z.number().int().positive().nullable().optional(),
    description: z.string().min(1).nullable().optional(),
  })
  .refine((v) => (v.amountCents ?? null) !== null || (v.description ?? null) !== null, {
    message: "Provide either a fixed amount or a description of the variable rule.",
  });

fineScheduleRouter.post("/", async (req, res) => {
  if (!canManageFineSchedule(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = bodySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const count = await prisma.fineScheduleItem.count();
  const item = await prisma.fineScheduleItem.create({
    data: {
      offense: parsed.data.offense,
      amountCents: parsed.data.amountCents ?? null,
      description: parsed.data.description ?? null,
      order: count,
    },
  });

  res.status(201).json(item);
});

fineScheduleRouter.patch("/:id", async (req, res) => {
  if (!canManageFineSchedule(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.fineScheduleItem.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: "Offense not found" });
  }
  const parsed = bodySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const item = await prisma.fineScheduleItem.update({
    where: { id: existing.id },
    data: {
      offense: parsed.data.offense,
      amountCents: parsed.data.amountCents ?? null,
      description: parsed.data.description ?? null,
    },
  });

  res.json(item);
});

fineScheduleRouter.delete("/:id", async (req, res) => {
  if (!canManageFineSchedule(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.fineScheduleItem.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: "Offense not found" });
  }
  await prisma.fineScheduleItem.delete({ where: { id: existing.id } });
  res.status(204).end();
});
