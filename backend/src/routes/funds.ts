import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canManageFundraising, isBoardRole } from "../permissions.js";

export const fundsRouter = Router();
fundsRouter.use(requireUser);

// Fundraising totals/breakdown are team-wide, not per-user data, and have no
// "own record" fallback the way quotas/fines do — so viewing is board-only.
fundsRouter.get("/", async (req, res) => {
  if (!isBoardRole(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
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

  await prisma.update.create({
    data: {
      authorId: req.currentUser!.id,
      tag: "FINANCE",
      content: `${req.currentUser!.name} logged a new fund: ${(fund.amountCents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })} from ${fund.source}.`,
      visibleToRoles: "CAPTAIN,FINANCE",
    },
  });

  res.status(201).json(fund);
});
