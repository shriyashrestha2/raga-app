import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditCompSection, type RoleName } from "../permissions.js";

// Competition Dashboard. Every role sees the shared schedule; the
// finance/production/logistics sections are visible to the Captain (all
// three) and to the one role that owns that section — every other role
// doesn't just have the field nulled out, the key is omitted from the JSON
// entirely (see shapeCompetition below), matching the PRD's "never receives
// data outside its section" rule.
export const competitionsRouter = Router();
competitionsRouter.use(requireUser);

const fullInclude = {
  financeSection: true,
  productionSection: true,
  logisticsSection: true,
  scheduleItems: { orderBy: { time: "asc" as const } },
};

type CompetitionWithSections = Awaited<ReturnType<typeof fetchOne>>;

function fetchOne(id: string) {
  return prisma.competition.findUnique({ where: { id }, include: fullInclude });
}

/** Per-role response shaping. Keys for sections the role can't see are
 * omitted from the returned object outright, not merely nulled. */
function shapeCompetition(comp: NonNullable<CompetitionWithSections>, role: RoleName) {
  const base = {
    id: comp.id,
    name: comp.name,
    date: comp.date,
    location: comp.location,
    scheduleItems: comp.scheduleItems,
  };

  if (role === "CAPTAIN") {
    return {
      ...base,
      financeSection: comp.financeSection,
      productionSection: comp.productionSection,
      logisticsSection: comp.logisticsSection,
    };
  }
  if (role === "FINANCE") {
    return { ...base, financeSection: comp.financeSection };
  }
  if (role === "PRODUCTION") {
    return { ...base, productionSection: comp.productionSection };
  }
  if (role === "LOGISTICS") {
    return { ...base, logisticsSection: comp.logisticsSection };
  }
  // RETURNER / NEWBIE: schedule only, no section data whatsoever.
  return base;
}

competitionsRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const competitions = await prisma.competition.findMany({
    include: fullInclude,
    orderBy: { date: "asc" },
  });
  res.json(competitions.map((c) => shapeCompetition(c, role)));
});

competitionsRouter.get("/:id", async (req, res) => {
  const role = req.currentUser!.role;
  const competition = await fetchOne(req.params.id);
  if (!competition) return res.status(404).json({ error: "Competition not found" });
  res.json(shapeCompetition(competition, role));
});

const createCompetitionSchema = z.object({
  name: z.string().min(1),
  date: z.coerce.date(),
  location: z.string().optional(),
});

competitionsRouter.post("/", async (req, res) => {
  if (req.currentUser!.role !== "CAPTAIN") {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createCompetitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const competition = await prisma.competition.create({
    data: {
      ...parsed.data,
      financeSection: { create: { budgetCents: 0, spentCents: 0 } },
      productionSection: { create: {} },
      logisticsSection: { create: {} },
    },
    include: fullInclude,
  });
  res.status(201).json(shapeCompetition(competition, "CAPTAIN"));
});

const updateFinanceSchema = z.object({
  budgetCents: z.number().int().nonnegative().optional(),
  spentCents: z.number().int().nonnegative().optional(),
  notes: z.string().optional(),
});

competitionsRouter.patch("/:id/finance", async (req, res) => {
  const role = req.currentUser!.role;
  if (!canEditCompSection(role, "FINANCE")) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateFinanceSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const existing = await prisma.compFinanceSection.findUnique({ where: { competitionId: req.params.id } });
  if (!existing) return res.status(404).json({ error: "Finance section not found" });
  const updated = await prisma.compFinanceSection.update({
    where: { competitionId: req.params.id },
    data: parsed.data,
  });
  res.json(updated);
});

const updateProductionSchema = z.object({
  musicStatus: z.string().optional(),
  costumeStatus: z.string().optional(),
  notes: z.string().optional(),
});

competitionsRouter.patch("/:id/production", async (req, res) => {
  const role = req.currentUser!.role;
  if (!canEditCompSection(role, "PRODUCTION")) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateProductionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const existing = await prisma.compProductionSection.findUnique({ where: { competitionId: req.params.id } });
  if (!existing) return res.status(404).json({ error: "Production section not found" });
  const updated = await prisma.compProductionSection.update({
    where: { competitionId: req.params.id },
    data: parsed.data,
  });
  res.json(updated);
});

const updateLogisticsSchema = z.object({
  travelPlan: z.string().optional(),
  lodging: z.string().optional(),
  transportationNotes: z.string().optional(),
});

competitionsRouter.patch("/:id/logistics", async (req, res) => {
  const role = req.currentUser!.role;
  if (!canEditCompSection(role, "LOGISTICS")) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateLogisticsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const existing = await prisma.compLogisticsSection.findUnique({ where: { competitionId: req.params.id } });
  if (!existing) return res.status(404).json({ error: "Logistics section not found" });
  const updated = await prisma.compLogisticsSection.update({
    where: { competitionId: req.params.id },
    data: parsed.data,
  });
  res.json(updated);
});

const createScheduleItemSchema = z.object({
  time: z.coerce.date(),
  label: z.string().min(1),
  notes: z.string().optional(),
});

competitionsRouter.post("/:id/schedule-items", async (req, res) => {
  if (req.currentUser!.role !== "CAPTAIN") {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = createScheduleItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const competition = await prisma.competition.findUnique({ where: { id: req.params.id } });
  if (!competition) return res.status(404).json({ error: "Competition not found" });
  const item = await prisma.compScheduleItem.create({
    data: { ...parsed.data, competitionId: req.params.id },
  });
  res.status(201).json(item);
});

const updateScheduleItemSchema = createScheduleItemSchema.partial();

competitionsRouter.patch("/:id/schedule-items/:itemId", async (req, res) => {
  if (req.currentUser!.role !== "CAPTAIN") {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateScheduleItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const item = await prisma.compScheduleItem.findUnique({ where: { id: req.params.itemId } });
  if (!item || item.competitionId !== req.params.id) {
    return res.status(404).json({ error: "Schedule item not found" });
  }
  const updated = await prisma.compScheduleItem.update({
    where: { id: req.params.itemId },
    data: parsed.data,
  });
  res.json(updated);
});

competitionsRouter.delete("/:id/schedule-items/:itemId", async (req, res) => {
  if (req.currentUser!.role !== "CAPTAIN") {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const item = await prisma.compScheduleItem.findUnique({ where: { id: req.params.itemId } });
  if (!item || item.competitionId !== req.params.id) {
    return res.status(404).json({ error: "Schedule item not found" });
  }
  await prisma.compScheduleItem.delete({ where: { id: req.params.itemId } });
  res.status(204).end();
});
