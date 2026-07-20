import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canManageQuotas } from "../permissions.js";

export const quotasRouter = Router();
quotasRouter.use(requireUser);

quotasRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const requestedUserId = typeof req.query.userId === "string" ? req.query.userId : undefined;

  const where = canManageQuotas(role)
    ? requestedUserId
      ? { userId: requestedUserId }
      : {}
    : { userId: req.currentUser!.id };

  const quotas = await prisma.quota.findMany({
    where,
    include: { user: true, contributions: { orderBy: { createdAt: "desc" } } },
    orderBy: { createdAt: "desc" },
  });

  res.json(quotas);
});

const createQuotaSchema = z.object({
  userId: z.string().min(1),
  label: z.string().min(1),
  unit: z.string().min(1),
  targetValue: z.coerce.number(),
  dueDate: z.coerce.date().optional(),
});

quotasRouter.post("/", async (req, res) => {
  if (!canManageQuotas(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createQuotaSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const quota = await prisma.quota.create({
    data: { ...parsed.data, createdById: req.currentUser!.id },
    include: { user: true, contributions: true },
  });
  res.status(201).json(quota);
});

// currentValue is deliberately not editable here — it's derived from the sum
// of contributions (see POST /:id/contributions), so the only way to change
// it is by logging (or, in principle, one day deleting) a contribution.
const updateQuotaSchema = z.object({
  label: z.string().min(1).optional(),
  unit: z.string().min(1).optional(),
  targetValue: z.coerce.number().optional(),
  dueDate: z.coerce.date().nullable().optional(),
});

quotasRouter.patch("/:id", async (req, res) => {
  if (!canManageQuotas(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.quota.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: "Quota not found" });
  }
  const parsed = updateQuotaSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const quota = await prisma.quota.update({
    where: { id: existing.id },
    data: parsed.data,
    include: { user: true, contributions: { orderBy: { createdAt: "desc" } } },
  });
  res.json(quota);
});

const createContributionSchema = z.object({
  event: z.string().min(1),
  amount: z.coerce.number(),
});

// Logs one itemized entry toward a quota (e.g. "Bake Sale — $45") and bumps
// currentValue by the same amount in one transaction, so the running total
// never drifts from the sum of what's actually logged.
quotasRouter.post("/:id/contributions", async (req, res) => {
  if (!canManageQuotas(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.quota.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: "Quota not found" });
  }
  const parsed = createContributionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const [, quota] = await prisma.$transaction([
    prisma.quotaContribution.create({
      data: {
        quotaId: existing.id,
        event: parsed.data.event,
        amount: parsed.data.amount,
        createdById: req.currentUser!.id,
      },
    }),
    prisma.quota.update({
      where: { id: existing.id },
      data: { currentValue: { increment: parsed.data.amount } },
      include: { user: true, contributions: { orderBy: { createdAt: "desc" } } },
    }),
  ]);

  res.status(201).json(quota);
});

quotasRouter.delete("/:id", async (req, res) => {
  if (!canManageQuotas(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.quota.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: "Quota not found" });
  }
  await prisma.quota.delete({ where: { id: existing.id } });
  res.status(204).end();
});
