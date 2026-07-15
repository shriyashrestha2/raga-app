import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";

export const videosRouter = Router();
videosRouter.use(requireUser);

videosRouter.get("/", async (req, res) => {
  const set = typeof req.query.set === "string" ? req.query.set : undefined;
  const competition = typeof req.query.competition === "string" ? req.query.competition : undefined;
  const videos = await prisma.video.findMany({
    where: {
      set: set && set !== "All" ? set : undefined,
      competition: competition && competition !== "All" ? competition : undefined,
    },
    include: { uploadedBy: true },
    orderBy: { date: "desc" },
  });
  res.json(videos);
});

const createVideoSchema = z.object({
  title: z.string().min(1),
  set: z.string().min(1),
  competition: z.string().optional(),
  url: z.string().url(),
  date: z.coerce.date().optional(),
  duration: z.string().optional(),
  thumbnail: z.string().url().optional(),
});

videosRouter.post("/", async (req, res) => {
  const parsed = createVideoSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const video = await prisma.video.create({
    data: { ...parsed.data, date: parsed.data.date ?? new Date(), uploadedById: req.currentUser!.id },
    include: { uploadedBy: true },
  });
  res.status(201).json(video);
});
