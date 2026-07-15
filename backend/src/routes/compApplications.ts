import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser, requireRole } from "../middleware/currentUser.js";

// Comp Applications — Captain/Logistics-only competition-application tracker.
// Gated router-wide, including GET, per the matrix's "no access at all" rule
// for every other role (see backend/src/permissions.ts:canAccessCompApplications).
export const compApplicationsRouter = Router();
compApplicationsRouter.use(requireUser, requireRole("CAPTAIN", "LOGISTICS"));

compApplicationsRouter.get("/", async (_req, res) => {
  const applications = await prisma.compApplication.findMany({
    include: { assignedTo: true, createdBy: true },
    orderBy: { deadline: "asc" },
  });
  res.json(applications);
});

compApplicationsRouter.get("/:id", async (req, res) => {
  const application = await prisma.compApplication.findUnique({
    where: { id: req.params.id },
    include: { assignedTo: true, createdBy: true },
  });
  if (!application) return res.status(404).json({ error: "Comp application not found" });
  res.json(application);
});

const createSchema = z.object({
  competitionName: z.string().min(1),
  deadline: z.coerce.date(),
  packetUrl: z.string().optional(),
  notes: z.string().optional(),
  assignedToId: z.string().optional(),
});

compApplicationsRouter.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const application = await prisma.compApplication.create({
    data: { ...parsed.data, createdById: req.currentUser!.id },
    include: { assignedTo: true, createdBy: true },
  });
  res.status(201).json(application);
});

const updateSchema = z.object({
  competitionName: z.string().min(1).optional(),
  deadline: z.coerce.date().optional(),
  status: z.enum(["NOT_STARTED", "IN_PROGRESS", "SUBMITTED", "ACCEPTED", "REJECTED"]).optional(),
  packetUrl: z.string().optional(),
  notes: z.string().optional(),
  assignedToId: z.string().nullable().optional(),
});

compApplicationsRouter.patch("/:id", async (req, res) => {
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const application = await prisma.compApplication.update({
    where: { id: req.params.id },
    data: parsed.data,
    include: { assignedTo: true, createdBy: true },
  });
  res.json(application);
});

compApplicationsRouter.delete("/:id", async (req, res) => {
  await prisma.compApplication.delete({ where: { id: req.params.id } });
  res.status(204).end();
});
