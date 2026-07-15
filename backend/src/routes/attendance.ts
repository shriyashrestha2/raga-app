import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditAttendance } from "../permissions.js";

export const attendanceRouter = Router();
attendanceRouter.use(requireUser);

attendanceRouter.get("/event/:eventId", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.eventId } });
  if (!event) return res.status(404).json({ error: "Event not found" });

  const records = await prisma.attendance.findMany({
    where: { eventId: event.id },
    include: { user: true },
  });
  res.json({
    canEdit: canEditAttendance(req.currentUser!.role, event.category),
    records,
  });
});

const markSchema = z.object({
  userId: z.string().min(1),
  status: z.enum(["PRESENT", "ABSENT", "LATE", "EXCUSED"]),
  notes: z.string().optional(),
});

attendanceRouter.put("/event/:eventId/mark", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.eventId } });
  if (!event) return res.status(404).json({ error: "Event not found" });
  if (!canEditAttendance(req.currentUser!.role, event.category)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = markSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { userId, status, notes } = parsed.data;
  const record = await prisma.attendance.upsert({
    where: { eventId_userId: { eventId: event.id, userId } },
    create: { eventId: event.id, userId, status, notes, markedById: req.currentUser!.id },
    update: { status, notes, markedById: req.currentUser!.id },
    include: { user: true },
  });
  res.json(record);
});
