import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canEditCalendarEvent } from "../permissions.js";

export const calendarRouter = Router();
calendarRouter.use(requireUser);

const CATEGORIES = ["FINANCE", "PRACTICE", "PRODUCTION", "SOCIAL", "PERFORMANCE", "LOGISTICS", "PR"] as const;
const ROLES = ["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "DANCER", "NEWBIE"] as const;

function rolesToString(roles: readonly string[] | undefined): string {
  return roles && roles.length ? roles.join(",") : "";
}

function rolesFromString(value: string): string[] {
  return value ? value.split(",") : [];
}

// Empty visibleToRoles means every role can see the event; otherwise the
// viewer's role must be explicitly included — there's no implicit Captain
// bypass, matching how the roles are picked at creation time.
function canViewCalendarEvent(role: string, visibleToRoles: string): boolean {
  const roles = rolesFromString(visibleToRoles);
  return roles.length === 0 || roles.includes(role);
}

function serializeEvent<T extends { visibleToRoles: string }>(event: T) {
  return { ...event, visibleToRoles: rolesFromString(event.visibleToRoles) };
}

calendarRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const currentUserId = req.currentUser!.id;
  const events = await prisma.calendarEvent.findMany({ orderBy: { date: "asc" } });
  res.json(
    events
      .filter((e) => canViewCalendarEvent(role, e.visibleToRoles))
      .map((e) => ({ ...serializeEvent(e), canEdit: canEditCalendarEvent(role, e.category, e.createdById, currentUserId) }))
  );
});

const createEventSchema = z.object({
  date: z.coerce.date(),
  category: z.enum(CATEGORIES),
  label: z.string().min(1),
  description: z.string().optional(),
  visibleToRoles: z.array(z.enum(ROLES)).optional(),
});

calendarRouter.post("/", async (req, res) => {
  const parsed = createEventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const role = req.currentUser!.role;
  let { category } = parsed.data;

  if (role !== "CAPTAIN") {
    // Finance/Production/Logistics/PR can only create events tagged to their
    // own role — the client-sent category is overridden, not merely checked.
    if (role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS" || role === "PR") {
      category = role;
    } else {
      return res.status(403).json({ error: "You don't have access to this." });
    }
  }

  const { visibleToRoles, ...rest } = parsed.data;
  const event = await prisma.calendarEvent.create({
    data: { ...rest, category, visibleToRoles: rolesToString(visibleToRoles), createdById: req.currentUser!.id },
  });
  res.status(201).json({ ...serializeEvent(event), canEdit: true });
});

const updateEventSchema = createEventSchema.partial();

calendarRouter.patch("/:id", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.id } });
  if (!event) return res.status(404).json({ error: "Event not found" });
  if (!canEditCalendarEvent(req.currentUser!.role, event.category, event.createdById, req.currentUser!.id)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const parsed = updateEventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { visibleToRoles, ...rest } = parsed.data;
  const updated = await prisma.calendarEvent.update({
    where: { id: event.id },
    data: { ...rest, ...(visibleToRoles !== undefined ? { visibleToRoles: rolesToString(visibleToRoles) } : {}) },
  });
  res.json({ ...serializeEvent(updated), canEdit: true });
});

calendarRouter.delete("/:id", async (req, res) => {
  const event = await prisma.calendarEvent.findUnique({ where: { id: req.params.id } });
  if (!event) return res.status(404).json({ error: "Event not found" });
  if (!canEditCalendarEvent(req.currentUser!.role, event.category, event.createdById, req.currentUser!.id)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  await prisma.calendarEvent.delete({ where: { id: event.id } });
  res.status(204).end();
});
