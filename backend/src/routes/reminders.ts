import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";

// Personal reminders — every role manages only their own; there's no
// manager/cross-user view here (unlike quotas/fines), so every check below
// is a plain ownerId === currentUser.id comparison rather than a
// permissions.ts capability.
export const remindersRouter = Router();
remindersRouter.use(requireUser);

const ROLES = ["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "DANCER", "NEWBIE"] as const;

function rolesToString(roles: readonly string[] | undefined): string {
  return roles && roles.length ? roles.join(",") : "";
}

remindersRouter.get("/", async (req, res) => {
  const topics = await prisma.reminderTopic.findMany({
    where: { ownerId: req.currentUser!.id },
    include: { reminders: { orderBy: { date: "asc" } } },
    orderBy: { createdAt: "asc" },
  });
  res.json(topics);
});

const createTopicSchema = z.object({ name: z.string().min(1) });

remindersRouter.post("/topics", async (req, res) => {
  const parsed = createTopicSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const existing = await prisma.reminderTopic.findUnique({
    where: { ownerId_name: { ownerId: req.currentUser!.id, name: parsed.data.name } },
  });
  if (existing) {
    return res.status(409).json({ error: "You already have a topic with that name." });
  }
  const topic = await prisma.reminderTopic.create({
    data: { name: parsed.data.name, ownerId: req.currentUser!.id },
    include: { reminders: true },
  });
  res.status(201).json(topic);
});

remindersRouter.delete("/topics/:id", async (req, res) => {
  const topic = await prisma.reminderTopic.findUnique({
    where: { id: req.params.id },
    include: { reminders: true },
  });
  if (!topic) return res.status(404).json({ error: "Topic not found" });
  if (topic.ownerId !== req.currentUser!.id) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const calendarEventIds = topic.reminders.map((r) => r.calendarEventId).filter((id): id is string => id != null);
  await prisma.$transaction([
    prisma.reminderTopic.delete({ where: { id: topic.id } }), // cascades reminders
    ...(calendarEventIds.length ? [prisma.calendarEvent.deleteMany({ where: { id: { in: calendarEventIds } } })] : []),
  ]);
  res.status(204).end();
});

const createReminderSchema = z.object({
  topicId: z.string().min(1),
  title: z.string().min(1),
  description: z.string().optional(),
  date: z.coerce.date(),
  addToCalendar: z.coerce.boolean().default(false),
  visibleToRoles: z.array(z.enum(ROLES)).optional(),
});

remindersRouter.post("/", async (req, res) => {
  const parsed = createReminderSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { topicId, title, description, date, addToCalendar, visibleToRoles } = parsed.data;

  const topic = await prisma.reminderTopic.findUnique({ where: { id: topicId } });
  if (!topic) return res.status(404).json({ error: "Topic not found" });
  if (topic.ownerId !== req.currentUser!.id) {
    return res.status(403).json({ error: "You don't have access to this." });
  }

  const reminder = await prisma.$transaction(async (tx) => {
    let calendarEventId: string | null = null;
    if (addToCalendar) {
      const event = await tx.calendarEvent.create({
        data: {
          date,
          category: "REMINDER",
          label: title,
          description,
          visibleToRoles: rolesToString(visibleToRoles),
          createdById: req.currentUser!.id,
        },
      });
      calendarEventId = event.id;
    }
    return tx.reminder.create({
      data: {
        topicId,
        title,
        description,
        date,
        addedToCalendar: addToCalendar,
        calendarEventId,
        ownerId: req.currentUser!.id,
      },
    });
  });

  res.status(201).json(reminder);
});

remindersRouter.delete("/:id", async (req, res) => {
  const reminder = await prisma.reminder.findUnique({ where: { id: req.params.id } });
  if (!reminder) return res.status(404).json({ error: "Reminder not found" });
  if (reminder.ownerId !== req.currentUser!.id) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  await prisma.$transaction([
    prisma.reminder.delete({ where: { id: reminder.id } }),
    ...(reminder.calendarEventId ? [prisma.calendarEvent.delete({ where: { id: reminder.calendarEventId } } as const)] : []),
  ]);
  res.status(204).end();
});
