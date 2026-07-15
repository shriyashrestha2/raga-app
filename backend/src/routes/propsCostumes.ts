import { Router, type Request } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { propsCostumesAccess } from "../permissions.js";

export const propsCostumesRouter = Router();
propsCostumesRouter.use(requireUser);

// GET / — list behavior depends on propsCostumesAccess(role):
//   FULL                 -> every item, full assignments list (with user relation)
//   OWN_ASSIGNMENTS_ONLY  -> only items where the caller has an assignment, and
//                            within each item only the caller's own assignment
//   BUDGET_ONLY / NONE    -> 403 (Finance uses /budget instead, Logistics has no access)
propsCostumesRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const mode = propsCostumesAccess(role);

  if (mode === "FULL") {
    const items = await prisma.propCostumeItem.findMany({
      include: { assignments: { include: { user: true } } },
      orderBy: { createdAt: "asc" },
    });
    return res.json(items);
  }

  if (mode === "OWN_ASSIGNMENTS_ONLY") {
    const currentUserId = req.currentUser!.id;
    const items = await prisma.propCostumeItem.findMany({
      where: { assignments: { some: { userId: currentUserId } } },
      include: { assignments: { where: { userId: currentUserId }, include: { user: true } } },
      orderBy: { createdAt: "asc" },
    });
    return res.json(items);
  }

  // BUDGET_ONLY and NONE have no access to the detail list endpoint.
  return res.status(403).json({ error: "You don't have access to this." });
});

// GET /budget — aggregate cost view for Captain/Production/Finance. No
// status/assignment/task detail — cost-only line items.
propsCostumesRouter.get("/budget", async (req, res) => {
  const role = req.currentUser!.role;
  const mode = propsCostumesAccess(role);
  if (mode !== "FULL" && mode !== "BUDGET_ONLY") {
    return res.status(403).json({ error: "You don't have access to this." });
  }

  const items = await prisma.propCostumeItem.findMany({
    select: { id: true, name: true, rentalCostCents: true },
    orderBy: { createdAt: "asc" },
  });

  const totalSpentCents = items.reduce((sum, item) => sum + (item.rentalCostCents ?? 0), 0);

  res.json({
    // There's no separate budget-allocation record in the schema yet, so the
    // "budget" figure is derived as the sum of known rental costs — i.e. the
    // committed spend is treated as the working budget total. If a real
    // allocated-budget field is added later, swap this for that value.
    totalBudgetCents: totalSpentCents,
    totalSpentCents,
    items,
  });
});

function requireFull(req: Request) {
  return propsCostumesAccess(req.currentUser!.role) === "FULL";
}

const createItemSchema = z.object({
  name: z.string().min(1),
  category: z.enum(["PROP", "COSTUME"]),
  status: z.enum(["NOT_STARTED", "IN_PROGRESS", "READY", "RENTED"]).optional(),
  rentalVendor: z.string().optional(),
  rentalCostCents: z.number().int().nonnegative().optional(),
  rentalDueDate: z.coerce.date().optional(),
  notes: z.string().optional(),
});

propsCostumesRouter.post("/", async (req, res) => {
  if (!requireFull(req)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const item = await prisma.propCostumeItem.create({
    data: { ...parsed.data, createdById: req.currentUser!.id },
    include: { assignments: { include: { user: true } } },
  });
  res.status(201).json(item);
});

const updateItemSchema = z.object({
  name: z.string().min(1).optional(),
  category: z.enum(["PROP", "COSTUME"]).optional(),
  status: z.enum(["NOT_STARTED", "IN_PROGRESS", "READY", "RENTED"]).optional(),
  rentalVendor: z.string().nullable().optional(),
  rentalCostCents: z.number().int().nonnegative().nullable().optional(),
  rentalDueDate: z.coerce.date().nullable().optional(),
  notes: z.string().nullable().optional(),
});

propsCostumesRouter.patch("/:id", async (req, res) => {
  if (!requireFull(req)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.propCostumeItem.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: "Item not found" });

  const parsed = updateItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const item = await prisma.propCostumeItem.update({
    where: { id: req.params.id },
    data: parsed.data,
    include: { assignments: { include: { user: true } } },
  });
  res.json(item);
});

propsCostumesRouter.delete("/:id", async (req, res) => {
  if (!requireFull(req)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.propCostumeItem.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: "Item not found" });

  await prisma.propCostumeAssignment.deleteMany({ where: { itemId: req.params.id } });
  await prisma.propCostumeItem.delete({ where: { id: req.params.id } });
  res.status(204).end();
});

const createAssignmentSchema = z.object({
  userId: z.string().min(1),
  size: z.string().optional(),
  task: z.string().optional(),
});

propsCostumesRouter.post("/:id/assignments", async (req, res) => {
  if (!requireFull(req)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const item = await prisma.propCostumeItem.findUnique({ where: { id: req.params.id } });
  if (!item) return res.status(404).json({ error: "Item not found" });

  const parsed = createAssignmentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { userId, size, task } = parsed.data;

  const targetUser = await prisma.user.findUnique({ where: { id: userId } });
  if (!targetUser) return res.status(400).json({ error: "Unknown user" });

  const assignment = await prisma.propCostumeAssignment.upsert({
    where: { itemId_userId: { itemId: req.params.id, userId } },
    create: { itemId: req.params.id, userId, size, task },
    update: { size, task },
    include: { user: true },
  });
  res.status(201).json(assignment);
});

const updateAssignmentSchema = z.object({
  size: z.string().nullable().optional(),
  task: z.string().nullable().optional(),
  status: z.string().min(1).optional(),
});

propsCostumesRouter.patch("/:id/assignments/:assignmentId", async (req, res) => {
  if (!requireFull(req)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const existing = await prisma.propCostumeAssignment.findUnique({ where: { id: req.params.assignmentId } });
  if (!existing || existing.itemId !== req.params.id) {
    return res.status(404).json({ error: "Assignment not found" });
  }

  const parsed = updateAssignmentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const assignment = await prisma.propCostumeAssignment.update({
    where: { id: req.params.assignmentId },
    data: parsed.data,
    include: { user: true },
  });
  res.json(assignment);
});
