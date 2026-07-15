import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser, requireRole } from "../middleware/currentUser.js";

// Captain-only agenda/timeline planning tool — distinct from the existing
// Practice/Rsvp headcount tab, which stays visible to every role. Gated
// router-wide, including GET, per the matrix's "no access at all" rule for
// every other role.
export const practicePlannerRouter = Router();
practicePlannerRouter.use(requireUser, requireRole("CAPTAIN"));

practicePlannerRouter.get("/", async (_req, res) => {
  const plans = await prisma.practicePlan.findMany({
    include: { agendaItems: { orderBy: { order: "asc" } } },
    orderBy: { date: "asc" },
  });
  res.json(plans);
});

practicePlannerRouter.get("/:id", async (req, res) => {
  const plan = await prisma.practicePlan.findUnique({
    where: { id: req.params.id },
    include: { agendaItems: { orderBy: { order: "asc" } } },
  });
  if (!plan) return res.status(404).json({ error: "Practice plan not found" });
  res.json(plan);
});

const createPlanSchema = z.object({
  practiceId: z.string().optional(),
  title: z.string().min(1),
  date: z.coerce.date(),
});

practicePlannerRouter.post("/", async (req, res) => {
  const parsed = createPlanSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const plan = await prisma.practicePlan.create({
    data: { ...parsed.data, createdById: req.currentUser!.id },
    include: { agendaItems: true },
  });
  res.status(201).json(plan);
});

const updatePlanSchema = createPlanSchema.partial();

practicePlannerRouter.patch("/:id", async (req, res) => {
  const parsed = updatePlanSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const plan = await prisma.practicePlan.update({ where: { id: req.params.id }, data: parsed.data });
  res.json(plan);
});

practicePlannerRouter.delete("/:id", async (req, res) => {
  await prisma.practicePlan.delete({ where: { id: req.params.id } });
  res.status(204).end();
});

const createAgendaItemSchema = z.object({
  order: z.number().int(),
  startOffsetMin: z.number().int(),
  durationMin: z.number().int(),
  label: z.string().min(1),
  notes: z.string().optional(),
});

practicePlannerRouter.post("/:id/agenda-items", async (req, res) => {
  const parsed = createAgendaItemSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const item = await prisma.practiceAgendaItem.create({ data: { ...parsed.data, planId: req.params.id } });
  res.status(201).json(item);
});

const updateAgendaItemSchema = createAgendaItemSchema.partial();

practicePlannerRouter.patch("/:id/agenda-items/:itemId", async (req, res) => {
  const parsed = updateAgendaItemSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const item = await prisma.practiceAgendaItem.update({ where: { id: req.params.itemId }, data: parsed.data });
  res.json(item);
});

practicePlannerRouter.delete("/:id/agenda-items/:itemId", async (req, res) => {
  await prisma.practiceAgendaItem.delete({ where: { id: req.params.itemId } });
  res.status(204).end();
});
