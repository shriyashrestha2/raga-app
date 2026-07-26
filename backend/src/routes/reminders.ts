import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canCreateReminder, isBoardRole, ownedCategory } from "../permissions.js";
import type { Prisma } from "@prisma/client";

// Shared team reminders — everyone sees the same filterable list; only
// Captains/board positions can create (see permissions.ts:canCreateReminder).
export const remindersRouter = Router();
remindersRouter.use(requireUser);

const CATEGORIES = ["FINANCE", "PRACTICE", "CAPTAINS", "PRODUCTION", "SOCIAL", "LOGISTICS"] as const;
const KINDS = ["RSVP", "TASK"] as const;

type ReminderWithRelations = Prisma.ReminderGetPayload<{
  include: { createdBy: true; rsvps: true; taskCompletions: true };
}>;

function serialize(reminder: ReminderWithRelations, userId: string) {
  return {
    id: reminder.id,
    title: reminder.title,
    description: reminder.description,
    date: reminder.date,
    category: reminder.category,
    type: reminder.type,
    createdBy: reminder.createdBy,
    rsvpYes: reminder.rsvps.filter((r) => r.response === "YES").length,
    rsvpNo: reminder.rsvps.filter((r) => r.response === "NO").length,
    myRsvp: reminder.rsvps.find((r) => r.userId === userId)?.response ?? null,
    doneCount: reminder.taskCompletions.length,
    doneByMe: reminder.taskCompletions.some((t) => t.userId === userId),
  };
}

async function fetchAndSerialize(id: string, userId: string) {
  const reminder = await prisma.reminder.findUniqueOrThrow({
    where: { id },
    include: { createdBy: true, rsvps: true, taskCompletions: true },
  });
  return serialize(reminder, userId);
}

remindersRouter.get("/", async (req, res) => {
  const category = typeof req.query.category === "string" ? req.query.category : undefined;
  const reminders = await prisma.reminder.findMany({
    where: category && category !== "All" ? { category: category as (typeof CATEGORIES)[number] } : undefined,
    include: { createdBy: true, rsvps: true, taskCompletions: true },
    orderBy: { date: "asc" },
  });
  res.json(reminders.map((r) => serialize(r, req.currentUser!.id)));
});

const createReminderSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  date: z.coerce.date(),
  type: z.enum(KINDS),
  category: z.enum(CATEGORIES),
});

remindersRouter.post("/", async (req, res) => {
  const role = req.currentUser!.role;
  if (!canCreateReminder(role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createReminderSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  // Board positions are locked to their own category (mirrors POST
  // /calendar's auto-scoping); Captains pick freely.
  const owned = ownedCategory(role);
  const category = owned ?? parsed.data.category;

  const reminder = await prisma.reminder.create({
    data: {
      title: parsed.data.title,
      description: parsed.data.description,
      date: parsed.data.date,
      type: parsed.data.type,
      category,
      createdById: req.currentUser!.id,
    },
    include: { createdBy: true, rsvps: true, taskCompletions: true },
  });
  res.status(201).json(serialize(reminder, req.currentUser!.id));
});

remindersRouter.delete("/:id", async (req, res) => {
  const reminder = await prisma.reminder.findUnique({ where: { id: req.params.id } });
  if (!reminder) return res.status(404).json({ error: "Reminder not found" });
  if (!isBoardRole(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  await prisma.reminder.delete({ where: { id: reminder.id } });
  res.status(204).end();
});

const rsvpSchema = z.object({ response: z.enum(["YES", "NO"]) });

remindersRouter.post("/:id/rsvp", async (req, res) => {
  const parsed = rsvpSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const reminder = await prisma.reminder.findUnique({ where: { id: req.params.id } });
  if (!reminder) return res.status(404).json({ error: "Reminder not found" });
  if (reminder.type !== "RSVP") {
    return res.status(400).json({ error: "This reminder isn't an RSVP reminder." });
  }

  await prisma.reminderRsvp.upsert({
    where: { reminderId_userId: { reminderId: reminder.id, userId: req.currentUser!.id } },
    create: { reminderId: reminder.id, userId: req.currentUser!.id, response: parsed.data.response },
    update: { response: parsed.data.response },
  });
  res.json(await fetchAndSerialize(reminder.id, req.currentUser!.id));
});

const doneSchema = z.object({ done: z.boolean() });

remindersRouter.post("/:id/done", async (req, res) => {
  const parsed = doneSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const reminder = await prisma.reminder.findUnique({ where: { id: req.params.id } });
  if (!reminder) return res.status(404).json({ error: "Reminder not found" });
  if (reminder.type !== "TASK") {
    return res.status(400).json({ error: "This reminder isn't a task reminder." });
  }

  if (parsed.data.done) {
    await prisma.reminderTaskCompletion.upsert({
      where: { reminderId_userId: { reminderId: reminder.id, userId: req.currentUser!.id } },
      create: { reminderId: reminder.id, userId: req.currentUser!.id },
      update: {},
    });
  } else {
    await prisma.reminderTaskCompletion.deleteMany({
      where: { reminderId: reminder.id, userId: req.currentUser!.id },
    });
  }
  res.json(await fetchAndSerialize(reminder.id, req.currentUser!.id));
});
