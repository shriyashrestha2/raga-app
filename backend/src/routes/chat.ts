import type { NextFunction, Request, Response } from "express";
import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireUser } from "../middleware/currentUser.js";
import { canPinChatMessage } from "../permissions.js";
import { chatAttachmentStorage } from "../storage.js";
import type { Prisma } from "@prisma/client";

// Chat tab: one flat, team-wide channel — every role can post and react,
// there's no per-message permission gating (unlike Update/Reminder, which
// scope who can create). Role badges (board vs. non-board) are a display
// concern the client derives from `author.role`, not something the server
// encodes per message. Pinning is the one board-only action here (see
// permissions.ts's canPinChatMessage).
export const chatRouter = Router();
chatRouter.use(requireUser);

const MESSAGE_LIMIT = 200;
const MAX_ATTACHMENTS = 10;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
});

type ChatMessageWithRelations = Prisma.ChatMessageGetPayload<{
  include: { author: true; reactions: true; attachments: true };
}>;

const MESSAGE_INCLUDE = {
  author: true,
  reactions: { orderBy: { createdAt: "asc" } },
  attachments: { orderBy: { createdAt: "asc" } },
} satisfies Prisma.ChatMessageInclude;

function serialize(message: ChatMessageWithRelations, userId: string) {
  // Reactions come back grouped into (emoji -> {count, reactedByMe}) rather
  // than the raw per-user rows — the client only ever needs the summary, and
  // this keeps the reaction pill order stable (first-emoji-used-first)
  // rather than re-sorting every poll.
  const order: string[] = [];
  const counts = new Map<string, { count: number; reactedByMe: boolean }>();
  for (const reaction of message.reactions) {
    if (!counts.has(reaction.emoji)) {
      counts.set(reaction.emoji, { count: 0, reactedByMe: false });
      order.push(reaction.emoji);
    }
    const entry = counts.get(reaction.emoji)!;
    entry.count += 1;
    if (reaction.userId === userId) entry.reactedByMe = true;
  }
  return {
    id: message.id,
    content: message.content,
    pinned: message.pinned,
    createdAt: message.createdAt,
    author: message.author,
    attachments: message.attachments.map((a) => ({
      id: a.id,
      kind: a.kind,
      url: a.url,
      fileName: a.fileName,
      mimeType: a.mimeType,
      fileSizeBytes: a.fileSizeBytes,
    })),
    reactions: order.map((emoji) => ({ emoji, ...counts.get(emoji)! })),
  };
}

chatRouter.get("/", async (req, res) => {
  // Newest-first fetch capped at MESSAGE_LIMIT, then reversed back to
  // chronological order — cheaper than an offset/cursor scheme for a single
  // flat channel with no history browsing requirement yet.
  const messages = await prisma.chatMessage.findMany({
    include: MESSAGE_INCLUDE,
    orderBy: { createdAt: "desc" },
    take: MESSAGE_LIMIT,
  });
  res.json(messages.reverse().map((m) => serialize(m, req.currentUser!.id)));
});

// Separate from the main feed since a pinned message can fall outside the
// MESSAGE_LIMIT window above — the "Pinned" sheet needs all of them, not
// just whatever's in the last 200.
chatRouter.get("/pinned", async (req, res) => {
  const messages = await prisma.chatMessage.findMany({
    where: { pinned: true },
    include: MESSAGE_INCLUDE,
    orderBy: { createdAt: "desc" },
  });
  res.json(messages.map((m) => serialize(m, req.currentUser!.id)));
});

const createMessageSchema = z.object({
  content: z.string().trim().max(2000).optional(),
});

chatRouter.post("/", upload.array("attachments", MAX_ATTACHMENTS), async (req, res) => {
  const parsed = createMessageSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const files = (req.files as Express.Multer.File[] | undefined) ?? [];
  const content = parsed.data.content ?? "";
  if (!content && files.length === 0) {
    return res.status(400).json({ error: "A message needs text or at least one attachment" });
  }

  const attachments = await Promise.all(
    files.map(async (file) => {
      const { url } = await chatAttachmentStorage.save({
        buffer: file.buffer,
        originalName: file.originalname,
        mimeType: file.mimetype,
      });
      return {
        kind: file.mimetype.startsWith("image/") ? ("IMAGE" as const) : ("FILE" as const),
        url,
        fileName: file.originalname,
        mimeType: file.mimetype,
        fileSizeBytes: file.size,
      };
    })
  );

  const message = await prisma.chatMessage.create({
    data: {
      content,
      authorId: req.currentUser!.id,
      attachments: { create: attachments },
    },
    include: MESSAGE_INCLUDE,
  });
  res.status(201).json(serialize(message, req.currentUser!.id));
});

const reactSchema = z.object({
  emoji: z.string().trim().min(1).max(8),
});

chatRouter.post("/:id/react", async (req, res) => {
  const parsed = reactSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const message = await prisma.chatMessage.findUnique({ where: { id: req.params.id } });
  if (!message) return res.status(404).json({ error: "Message not found" });

  const existing = await prisma.chatReaction.findUnique({
    where: {
      messageId_userId: { messageId: message.id, userId: req.currentUser!.id },
    },
  });

  // One reaction per person per message: reacting with the same emoji again
  // clears it, reacting with a different emoji replaces theirs.
  if (existing && existing.emoji === parsed.data.emoji) {
    await prisma.chatReaction.delete({ where: { id: existing.id } });
  } else if (existing) {
    await prisma.chatReaction.update({ where: { id: existing.id }, data: { emoji: parsed.data.emoji } });
  } else {
    await prisma.chatReaction.create({
      data: { messageId: message.id, userId: req.currentUser!.id, emoji: parsed.data.emoji },
    });
  }

  const updated = await prisma.chatMessage.findUniqueOrThrow({
    where: { id: message.id },
    include: MESSAGE_INCLUDE,
  });
  res.json(serialize(updated, req.currentUser!.id));
});

const pinSchema = z.object({ pinned: z.boolean() });

chatRouter.patch("/:id/pin", async (req, res) => {
  const parsed = pinSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  if (!canPinChatMessage(req.currentUser!.role)) {
    return res.status(403).json({ error: "You don't have access to this." });
  }
  const message = await prisma.chatMessage.findUnique({ where: { id: req.params.id } });
  if (!message) return res.status(404).json({ error: "Message not found" });

  const updated = await prisma.chatMessage.update({
    where: { id: message.id },
    data: { pinned: parsed.data.pinned },
    include: MESSAGE_INCLUDE,
  });
  res.json(serialize(updated, req.currentUser!.id));
});

// Converts multer errors (oversized file, too many attachments) into JSON
// instead of falling through to Express's default HTML error page — mirrors
// routes/videos.ts's equivalent handler.
chatRouter.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
  if (err instanceof Error) {
    return res.status(400).json({ error: err.message });
  }
  next(err);
});
