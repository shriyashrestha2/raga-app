import { Router } from "express";
import { prisma } from "../prisma.js";

export const updatesRouter = Router();

updatesRouter.get("/", async (_req, res) => {
  const updates = await prisma.update.findMany({
    include: { author: true },
    orderBy: [{ pinned: "desc" }, { createdAt: "desc" }],
  });
  res.json(updates);
});
