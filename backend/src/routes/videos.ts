import type { NextFunction, Request, Response } from "express";
import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { videoStorage } from "../storage.js";

export const videosRouter = Router();
videosRouter.use(requireUser);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 300 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith("video/")) {
      cb(new Error("Only video files are allowed"));
      return;
    }
    cb(null, true);
  },
});

videosRouter.get("/", async (req, res) => {
  const set = typeof req.query.set === "string" ? req.query.set : undefined;
  const competition = typeof req.query.competition === "string" ? req.query.competition : undefined;
  const videos = await prisma.video.findMany({
    where: {
      set: set && set !== "All" ? set : undefined,
      competition: competition && competition !== "All" ? competition : undefined,
    },
    include: { uploadedBy: true },
    orderBy: [{ pinned: "desc" }, { date: "desc" }],
  });
  res.json(videos);
});

// Videos are uploaded as real files (multipart), not linked from YouTube —
// `url` below is always a path served by our own /uploads static route (see
// storage.ts), never an arbitrary external link.
const createVideoSchema = z.object({
  title: z.string().min(1),
  set: z.string().min(1),
  competition: z.string().optional(),
  date: z.coerce.date().optional(),
  duration: z.string().optional(),
  pinned: z
    .union([z.literal("true"), z.literal("false")])
    .optional()
    .transform((v) => v === "true"),
  pinLabel: z.string().optional(),
});

videosRouter.post("/", upload.single("file"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "A video file is required" });
  }
  const parsed = createVideoSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  if (parsed.data.pinned && !parsed.data.pinLabel?.trim()) {
    return res.status(400).json({ error: "pinLabel is required when pinning a video" });
  }

  const { url } = await videoStorage.save({
    buffer: req.file.buffer,
    originalName: req.file.originalname,
    mimeType: req.file.mimetype,
  });

  const video = await prisma.video.create({
    data: {
      title: parsed.data.title,
      set: parsed.data.set,
      competition: parsed.data.competition,
      date: parsed.data.date ?? new Date(),
      duration: parsed.data.duration,
      pinned: parsed.data.pinned ?? false,
      pinLabel: parsed.data.pinned ? parsed.data.pinLabel!.trim() : null,
      url,
      uploadedById: req.currentUser!.id,
    },
    include: { uploadedBy: true },
  });
  res.status(201).json(video);
});

const patchVideoSchema = z.object({
  pinned: z.boolean(),
  pinLabel: z.string().optional(),
});

// Any authenticated user may pin/unpin any video — Video has no existing
// ownership or board-only gating (unlike Update/Reminder), so this doesn't
// introduce a new restriction model.
videosRouter.patch("/:id", async (req, res) => {
  const parsed = patchVideoSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  if (parsed.data.pinned && !parsed.data.pinLabel?.trim()) {
    return res.status(400).json({ error: "pinLabel is required when pinning a video" });
  }

  const video = await prisma.video.findUnique({ where: { id: req.params.id } });
  if (!video) return res.status(404).json({ error: "Video not found" });

  const updated = await prisma.video.update({
    where: { id: video.id },
    data: {
      pinned: parsed.data.pinned,
      pinLabel: parsed.data.pinned ? parsed.data.pinLabel!.trim() : null,
    },
    include: { uploadedBy: true },
  });
  res.json(updated);
});

// Converts multer/file-filter errors (e.g. wrong mime type, oversized file)
// into JSON instead of falling through to Express's default HTML error page.
videosRouter.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
  if (err instanceof Error) {
    return res.status(400).json({ error: err.message });
  }
  next(err);
});
