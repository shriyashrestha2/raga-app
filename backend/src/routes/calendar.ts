import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditCalendarEvent } from "../permissions.js";

export const calendarRouter = Router();
calendarRouter.use(requireUser);

const CATEGORIES = ["FINANCE", "PRACTICE", "PRODUCTION", "SOCIAL", "PERFORMANCE", "LOGISTICS"] as const;

calendarRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const events = await prisma.calendarEvent.findMany({ orderBy: { date: "asc" } });
  res.json(events.map((e) => ({ ...e, canEdit: canEditCalendarEvent(role, e.category) })));
});

const createEventSchema = z.object({
  date: z.coerce.date(),
  category: z.enum(CATEGORIES),
  label: z.string().min(1),
  description: z.string().optional(),
});

calendarRouter.post("/", async (req, res) => {
  const parsed = createEventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const role = req.currentUser!.role;
  let { category } = parsed.data;

  if (role !== "CAPTAIN") {
    // Finance/Production/Logistics can only create events tagged to their
    // own role — the client-sent category is overridden, not merely checked.
    if (role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS") {
      category = role;
    } else {
      return res.status(403).json({ error: "You don't have access to this." });
    }
  }

  const event = await prisma.calendarEvent.create({
    data: { ...parsed.data, category, createdById: req.currentUser!.id },
  });
  res.status(201).json({ ...event, canEdit: true });
});

const updateEventSchema = createEventSchema.partial();

calendarRouter.patch("/:id", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.id } });
  if (!event) return res.status(404).json({ error: "Event not found" });
  if (!canEditCalendarEvent(req.currentUser!.role, event.category)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateEventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const updated = await prisma.calendarEvent.update({ where: { id: event.id }, data: parsed.data });
  res.json({ ...updated, canEdit: true });
});

calendarRouter.delete("/:id", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.id } });
  if (!event) return res.status(404).json({ error: "Event not found" });
  if (!canEditCalendarEvent(req.currentUser!.role, event.category)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  await prisma.calendarEvent.delete({ where: { id: event.id } });
  res.status(204).end();
});
