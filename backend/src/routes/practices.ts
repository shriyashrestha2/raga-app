import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";

export const practicesRouter = Router();

function summarize(practice: {
  id: string;
  date: Date;
  location: string;
  focus: string;
  reminder: string | null;
  rsvps: { userId: string; response: "YES" | "NO"; reason: string | null }[];
}, currentUserId?: string) {
  const rsvpYes = practice.rsvps.filter((r) => r.response === "YES").length;
  const rsvpNo = practice.rsvps.filter((r) => r.response === "NO").length;
  const mine = currentUserId
    ? practice.rsvps.find((r) => r.userId === currentUserId)
    : undefined;

  return {
    id: practice.id,
    date: practice.date,
    location: practice.location,
    focus: practice.focus,
    reminder: practice.reminder,
    rsvpYes,
    rsvpNo,
    myRsvp: mine ? { response: mine.response, reason: mine.reason } : null,
  };
}

// Full per-dancer breakdown, captains only (per PRD: RSVP reasons visible to captains).
function captainDetail(practice: {
  rsvps: { user: { name: string }; response: "YES" | "NO"; reason: string | null }[];
}) {
  return practice.rsvps.map((r) => ({
    name: r.user.name,
    response: r.response,
    reason: r.reason,
  }));
}

practicesRouter.get("/", async (req, res) => {
  const currentUserId = typeof req.query.userId === "string" ? req.query.userId : undefined;
  const asCaptain = req.query.role === "CAPTAIN";

  const practices = await prisma.practice.findMany({
    include: { rsvps: { include: { user: true } } },
    orderBy: { date: "asc" },
  });

  res.json(
    practices.map((p) => ({
      ...summarize(p, currentUserId),
      detail: asCaptain ? captainDetail(p) : undefined,
    }))
  );
});

const createPracticeSchema = z.object({
  date: z.coerce.date(),
  location: z.string().min(1),
  focus: z.string().min(1),
  reminder: z.string().optional(),
});

practicesRouter.post("/", async (req, res) => {
  const parsed = createPracticeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const practice = await prisma.practice.create({ data: parsed.data });
  res.status(201).json(practice);
});

const rsvpSchema = z
  .object({
    userId: z.string().min(1),
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
  const { userId, response, reason } = parsed.data;
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
