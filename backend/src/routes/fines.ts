import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canManageFines, isBoardRole } from "../permissions.js";

export const finesRouter = Router();
finesRouter.use(requireUser);

finesRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const currentUserId = req.currentUser!.id;
  const queryUserId = typeof req.query.userId === "string" ? req.query.userId : undefined;

  // Board roles may optionally filter by any target user's id; everyone else
  // is force-filtered to their own fines regardless of what they pass in the
  // query string — the client-sent userId is never trusted for non-board.
  const where = isBoardRole(role)
    ? queryUserId
      ? { userId: queryUserId }
      : {}
    : { userId: currentUserId };

  const fines = await prisma.fine.findMany({
    where,
    include: { user: true, issuedBy: true },
    orderBy: { issuedAt: "desc" },
  });

  res.json(fines);
});

const createFineSchema = z.object({
  userId: z.string().min(1),
  amountCents: z.number().int().positive(),
  reason: z.string().min(1),
  status: z.enum(["UNPAID", "PAID", "WAIVED"]).optional(),
  issuedAt: z.coerce.date().optional(),
  dueDate: z.coerce.date().optional(),
});

finesRouter.post("/", async (req, res) => {
  if (!canManageFines(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createFineSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const target = await prisma.user.findUnique({ where: { id: parsed.data.userId } });
  if (!target) {
    return res.status(404).json({ error: "Target user not found" });
  }

  const fine = await prisma.fine.create({
    data: {
      userId: parsed.data.userId,
      amountCents: parsed.data.amountCents,
      reason: parsed.data.reason,
      issuedById: req.currentUser!.id,
      status: parsed.data.status,
      issuedAt: parsed.data.issuedAt,
      dueDate: parsed.data.dueDate,
      paidAt: parsed.data.status === "PAID" ? (parsed.data.issuedAt ?? new Date()) : undefined,
    },
    include: { user: true, issuedBy: true },
  });

  // dueDate is stored as a UTC-midnight, date-only value — format it in UTC
  // so it doesn't shift a day back for servers running west of UTC.
  const dueDateNote = fine.dueDate ? ` Due ${fine.dueDate.toLocaleDateString("en-US", { timeZone: "UTC" })}.` : "";
  await prisma.update.create({
    data: {
      authorId: req.currentUser!.id,
      tag: "FINANCE",
      content: `You've been issued a fine of ${(fine.amountCents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })} for ${fine.reason}.${dueDateNote}`,
      targetUserId: fine.userId,
      relatedFineId: fine.id,
    },
  });

  res.status(201).json(fine);
});

const updateFineSchema = z.object({
  status: z.enum(["UNPAID", "PAID", "WAIVED"]),
});

finesRouter.patch("/:id", async (req, res) => {
  if (!canManageFines(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateFineSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const fine = await prisma.fine.findUnique({ where: { id: req.params.id } });
  if (!fine) {
    return res.status(404).json({ error: "Fine not found" });
  }

  const updated = await prisma.fine.update({
    where: { id: fine.id },
    data: {
      status: parsed.data.status,
      paidAt: parsed.data.status === "PAID" ? new Date() : null,
    },
    include: { user: true, issuedBy: true },
  });

  res.json(updated);
});

finesRouter.delete("/:id", async (req, res) => {
  if (!canManageFines(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const fine = await prisma.fine.findUnique({ where: { id: req.params.id } });
  if (!fine) {
    return res.status(404).json({ error: "Fine not found" });
  }
  await prisma.fine.delete({ where: { id: fine.id } });
  res.status(204).end();
});
