import { Router } from "express";
import { prisma } from "../prisma.js";

export const calendarRouter = Router();

calendarRouter.get("/", async (_req, res) => {
  const events = await prisma.calendarEvent.findMany({ orderBy: { date: "asc" } });
  res.json(events);
});
