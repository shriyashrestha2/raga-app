import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditPracticeAttendance, canCreatePractice, canViewPracticeDetail } from "../permissions.js";

export const practicesRouter = Router();
practicesRouter.use(requireUser);

function summarize(practice: {
  id: string;
  date: Date;
  location: string;
  focus: string;
  reminder: string | null;
  kind: "PRACTICE" | "PROPS_DAY";
  rsvps: { userId: string; response: "YES" | "NO"; reason: string | null }[];
  attendance: { userId: string; status: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED" }[];
}, currentUserId: string) {
  const rsvpYes = practice.rsvps.filter((r) => r.response === "YES").length;
  const rsvpNo = practice.rsvps.filter((r) => r.response === "NO").length;
  const mine = practice.rsvps.find((r) => r.userId === currentUserId);
  const myAttendance = practice.attendance.find((a) => a.userId === currentUserId);

  return {
    id: practice.id,
    date: practice.date,
    location: practice.location,
    focus: practice.focus,
    reminder: practice.reminder,
    kind: practice.kind,
    rsvpYes,
    rsvpNo,
    myRsvp: mine ? { response: mine.response, reason: mine.reason } : null,
    myAttendance: myAttendance?.status ?? null,
  };
}

// Full per-dancer breakdown — visible per canViewPracticeDetail (Captain
// always, Production only on PROPS_DAY sessions they run).
function practiceDetail(practice: {
  rsvps: { user: { name: string }; response: "YES" | "NO"; reason: string | null }[];
}) {
  return practice.rsvps.map((r) => ({
    name: r.user.name,
    response: r.response,
    reason: r.reason,
  }));
}

practicesRouter.get("/", async (req, res) => {
  const currentUserId = req.currentUser!.id;
  const role = req.currentUser!.role;

  const practices = await prisma.practice.findMany({
    include: { rsvps: { include: { user: true } }, attendance: true },
    orderBy: { date: "asc" },
  });

  res.json(
    practices.map((p) => ({
      ...summarize(p, currentUserId),
      detail: canViewPracticeDetail(role, p.kind) ? practiceDetail(p) : undefined,
    }))
  );
});

const createPracticeSchema = z.object({
  date: z.coerce.date(),
  location: z.string().min(1),
  focus: z.string().min(1),
  reminder: z.string().optional(),
  kind: z.enum(["PRACTICE", "PROPS_DAY"]).default("PRACTICE"),
});

practicesRouter.post("/", async (req, res) => {
  const parsed = createPracticeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  if (!canCreatePractice(req.currentUser!.role, parsed.data.kind)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const practice = await prisma.practice.create({ data: parsed.data });
  res.status(201).json(practice);
});

const rsvpSchema = z
  .object({
    response: z.enum(["YES", "NO"]),
    reason: z.string().trim().min(1).optional(),
  })
  .refine((data) => data.response === "YES" || !!data.reason, {
    message: "A short reason is required when declining (RSVP: No).",
    path: ["reason"],
  });

practicesRouter.post("/:id/rsvp", async (req, res) => {
  const parsed = rsvpSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const userId = req.currentUser!.id;
  const { response, reason } = parsed.data;
  const practiceId = req.params.id;

  const practice = await prisma.practice.findUnique({ where: { id: practiceId } });
  if (!practice) {
    return res.status(404).json({ error: "Practice not found" });
  }

  const rsvp = await prisma.rsvp.upsert({
    where: { practiceId_userId: { practiceId, userId } },
    create: { practiceId, userId, response, reason: response === "NO" ? reason : null },
    update: { response, reason: response === "NO" ? reason : null },
  });

  res.json(rsvp);
});

// Captain-only dashboard: every team member's attendance status for one
// practice session (unmarked members are included with status: null so the
// dashboard can show them alongside marked ones).
practicesRouter.get("/:id/attendance", async (req, res) => {
  if (!canEditPracticeAttendance(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const practiceId = req.params.id;
  const practice = await prisma.practice.findUnique({ where: { id: practiceId } });
  if (!practice) {
    return res.status(404).json({ error: "Practice not found" });
  }

  const [users, records] = await Promise.all([
    prisma.user.findMany({ orderBy: { name: "asc" } }),
    prisma.practiceAttendance.findMany({ where: { practiceId } }),
  ]);
  const byUserId = new Map(records.map((r) => [r.userId, r.status]));

  res.json({
    canEdit: true,
    records: users.map((u) => ({
      userId: u.id,
      name: u.name,
      initials: u.initials,
      role: u.role,
      status: byUserId.get(u.id) ?? null,
    })),
  });
});

const markPracticeAttendanceSchema = z.object({
  userId: z.string().min(1),
  status: z.enum(["PRESENT", "ABSENT", "LATE"]),
});

practicesRouter.put("/:id/attendance/mark", async (req, res) => {
  if (!canEditPracticeAttendance(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = markPracticeAttendanceSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const practiceId = req.params.id;
  const practice = await prisma.practice.findUnique({ where: { id: practiceId } });
  if (!practice) {
    return res.status(404).json({ error: "Practice not found" });
  }
  const { userId, status } = parsed.data;

  const record = await prisma.practiceAttendance.upsert({
    where: { practiceId_userId: { practiceId, userId } },
    create: { practiceId, userId, status, markedById: req.currentUser!.id },
    update: { status, markedById: req.currentUser!.id },
  });
  res.json(record);
});

const markAllPracticeAttendanceSchema = z.object({
  status: z.enum(["PRESENT", "ABSENT", "LATE"]),
});

practicesRouter.put("/:id/attendance/mark-all", async (req, res) => {
  if (!canEditPracticeAttendance(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = markAllPracticeAttendanceSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const practiceId = req.params.id;
  const practice = await prisma.practice.findUnique({ where: { id: practiceId } });
  if (!practice) {
    return res.status(404).json({ error: "Practice not found" });
  }
  const { status } = parsed.data;

  const users = await prisma.user.findMany({ select: { id: true } });
  await prisma.$transaction(
    users.map((u) =>
      prisma.practiceAttendance.upsert({
        where: { practiceId_userId: { practiceId, userId: u.id } },
        create: { practiceId, userId: u.id, status, markedById: req.currentUser!.id },
        update: { status, markedById: req.currentUser!.id },
      })
    )
  );
  res.status(204).send();
});
