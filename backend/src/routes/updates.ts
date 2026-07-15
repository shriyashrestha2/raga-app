import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canPostAnnouncement, type RoleName } from "../permissions.js";

export const updatesRouter = Router();
updatesRouter.use(requireUser);

updatesRouter.get("/", async (_req, res) => {
  const updates = await prisma.update.findMany({
    include: { author: true },
    orderBy: [{ pinned: "desc" }, { createdAt: "desc" }],
  });
  res.json(updates);
});

const ROLES = ["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "DANCER", "NEWBIE"] as const;

const createUpdateSchema = z.object({
  tag: z.enum(["ANNOUNCEMENT", "COSTUME_LOGISTICS", "CHOREO_NOTES"]),
  content: z.string().min(1),
  pinned: z.boolean().optional(),
  audienceRole: z.enum(ROLES).nullable().optional(),
});

updatesRouter.post("/", async (req, res) => {
  const parsed = createUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const role = req.currentUser!.role;
  const audienceRole = (parsed.data.audienceRole ?? null) as RoleName | null;

  if (!canPostAnnouncement(role, audienceRole)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }

  const update = await prisma.update.create({
    data: {
      authorId: req.currentUser!.id,
      tag: parsed.data.tag,
      content: parsed.data.content,
      pinned: parsed.data.pinned ?? false,
      audienceRole: audienceRole ?? undefined,
    },
    include: { author: true },
  });
  res.status(201).json(update);
});
