import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canManageFundraising } from "../permissions.js";

export const fundsRouter = Router();
fundsRouter.use(requireUser);

// Fundraising totals/breakdown are team-wide, not per-user data, so every
// authenticated role can read the list — only logging a new fund is gated.
fundsRouter.get("/", async (_req, res) => {
  const funds = await prisma.fund.findMany({
    include: { createdBy: true },
    orderBy: { dateAdded: "desc" },
  });
  res.json(funds);
});

const createFundSchema = z.object({
  amountCents: z.number().int().positive(),
  source: z.string().min(1),
  dateAdded: z.coerce.date(),
});

fundsRouter.post("/", async (req, res) => {
  if (!canManageFundraising(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createFundSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const fund = await prisma.fund.create({
    data: { ...parsed.data, createdById: req.currentUser!.id },
    include: { createdBy: true },
  });

  res.status(201).json(fund);
});
