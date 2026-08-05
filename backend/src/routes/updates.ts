import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canPostAnnouncement, isBoardRole, type RoleName } from "../permissions.js";

export const updatesRouter = Router();
updatesRouter.use(requireUser);

const ROLES = ["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "RETURNER", "NEWBIE"] as const;

function rolesToString(roles: readonly string[] | undefined): string {
  return roles && roles.length ? roles.join(",") : "";
}

function rolesFromString(value: string): string[] {
  return value ? value.split(",") : [];
}

// Empty visibleToRoles means every role can see the update; otherwise the
// viewer's role must be explicitly included. Distinct from audienceRole,
// which only scopes who is allowed to *post* to a non-Captain's own channel.
// A set targetUserId (fund/fine notifications) overrides all of that — it's
// a personal notification, visible only to that one recipient.
function canViewUpdate(currentUserId: string, role: string, update: { visibleToRoles: string; targetUserId: string | null }): boolean {
  if (update.targetUserId) return update.targetUserId === currentUserId;
  const roles = rolesFromString(update.visibleToRoles);
  return roles.length === 0 || roles.includes(role);
}

function serializeUpdate<T extends { visibleToRoles: string }>(update: T) {
  return { ...update, visibleToRoles: rolesFromString(update.visibleToRoles) };
}

updatesRouter.get("/", async (req, res) => {
  const role = req.currentUser!.role;
  const currentUserId = req.currentUser!.id;
  const updates = await prisma.update.findMany({
    include: { author: true },
    orderBy: { createdAt: "desc" },
  });
  res.json(updates.filter((u) => canViewUpdate(currentUserId, role, u)).map(serializeUpdate));
});

const createUpdateSchema = z.object({
  tag: z.enum(["ANNOUNCEMENT", "COSTUME_LOGISTICS", "CHOREO_NOTES"]),
  content: z.string().min(1),
  audienceRole: z.enum(ROLES).nullable().optional(),
  visibleToRoles: z.array(z.enum(ROLES)).optional(),
});

updatesRouter.post("/", async (req, res) => {
  const parsed = createUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const role = req.currentUser!.role;
  let audienceRole = (parsed.data.audienceRole ?? null) as RoleName | null;

  if (role !== "CAPTAIN" && (role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS")) {
    // Own-channel roles can only post under their own audience — the
    // client-sent value is overridden, not merely checked (mirrors
    // POST /calendar's category auto-scoping).
    audienceRole = role;
  }

  if (!canPostAnnouncement(role, audienceRole)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }

  const update = await prisma.update.create({
    data: {
      authorId: req.currentUser!.id,
      tag: parsed.data.tag,
      content: parsed.data.content,
      audienceRole: audienceRole ?? undefined,
      visibleToRoles: rolesToString(parsed.data.visibleToRoles),
    },
    include: { author: true },
  });
  res.status(201).json(serializeUpdate(update));
});

updatesRouter.delete("/:id", async (req, res) => {
  const update = await prisma.update.findUnique({ where: { id: req.params.id } });
  if (!update) return res.status(404).json({ error: "Update not found" });
  if (!isBoardRole(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  await prisma.update.delete({ where: { id: update.id } });
  res.status(204).end();
});
