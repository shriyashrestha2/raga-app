import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser, requireRole } from "../middleware/currentUser.js";

// Captain-dashboard-only widgets. Not a page, not visible to any other
// role — gated router-wide, including GET.
export const choreoRemindersRouter = Router();
choreoRemindersRouter.use(requireUser, requireRole("CAPTAIN"));

choreoRemindersRouter.get("/", async (_req, res) => {
  const reminders = await prisma.choreoReminder.findMany({ orderBy: { createdAt: "desc" } });
  res.json(reminders);
});

const createReminderSchema = z.object({
  label: z.string().min(1),
  kind: z.enum(["FORMATION", "CHOREO_NOTE"]),
});

choreoRemindersRouter.post("/", async (req, res) => {
  const parsed = createReminderSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const reminder = await prisma.choreoReminder.create({ data: { ...parsed.data, createdById: req.currentUser!.id } });
  res.status(201).json(reminder);
});

const updateReminderSchema = z.object({
  label: z.string().min(1).optional(),
  resolved: z.boolean().optional(),
});

choreoRemindersRouter.patch("/:id", async (req, res) => {
  const parsed = updateReminderSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const reminder = await prisma.choreoReminder.update({ where: { id: req.params.id }, data: parsed.data });
  res.json(reminder);
});

choreoRemindersRouter.delete("/:id", async (req, res) => {
  await prisma.choreoReminder.delete({ where: { id: req.params.id } });
  res.status(204).end();
});
