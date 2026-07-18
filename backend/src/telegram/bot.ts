import { Bot } from "grammy";
import { prisma } from "../prisma.js";
import type { UpdateTag } from "@prisma/client";
import { initialsOf } from "../util/initials.js";

/**
 * Roundup ingestion (PRD §4.1 / §5): a bot added as a member/admin of the
 * team's Telegram channel mirrors captain posts (or #update-tagged posts)
 * into the Update table. Disabled by default because there's no bot token
 * yet — see backend/README.md for BotFather setup steps. Flip
 * ENABLE_TELEGRAM=true once TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID are set.
 */

const HASHTAG_TAG: Record<string, UpdateTag> = {
  update: "ANNOUNCEMENT",
  announcement: "ANNOUNCEMENT",
  costume: "COSTUME_LOGISTICS",
  logistics: "COSTUME_LOGISTICS",
  choreo: "CHOREO_NOTES",
};

function detectTag(text: string): UpdateTag {
  const hashtags = text.toLowerCase().match(/#(\w+)/g) ?? [];
  for (const tag of hashtags) {
    const key = tag.slice(1);
    if (HASHTAG_TAG[key]) return HASHTAG_TAG[key];
  }
  return "ANNOUNCEMENT";
}

export function startTelegramBot() {
  if (process.env.ENABLE_TELEGRAM !== "true") {
    console.log("Telegram ingestion disabled (ENABLE_TELEGRAM != true). Using seeded/manual updates only.");
    return;
  }

  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) {
    console.warn("ENABLE_TELEGRAM=true but TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID are missing; skipping bot startup.");
    return;
  }

  const bot = new Bot(token);

  bot.on("message:text", async (ctx) => {
    if (String(ctx.chat.id) !== chatId) return; // only the configured team channel/group

    const text = ctx.message.text;
    const from = ctx.from;
    if (!from) return;

    const isTaggedUpdate = /#update/i.test(text);

    const author = await prisma.user.findUnique({ where: { telegramId: String(from.id) } });

    // Filtering rule (PRD §4.1): only captains, or any #update-tagged message, get pulled in.
    const isCaptainPost = author?.role === "CAPTAIN";
    if (!isCaptainPost && !isTaggedUpdate) return;

    const authorId =
      author?.id ??
      (
        await prisma.user.create({
          data: {
            name: from.first_name + (from.last_name ? ` ${from.last_name}` : ""),
            initials: initialsOf(from.first_name),
            role: "RETURNER",
            telegramId: String(from.id),
          },
        })
      ).id;

    await prisma.update.create({
      data: {
        authorId,
        tag: detectTag(text),
        content: text,
        telegramMessageId: `${ctx.chat.id}:${ctx.message.message_id}`,
      },
    });
  });

  bot.catch((err) => console.error("Telegram bot error:", err));

  bot.start();
  console.log("Telegram bot polling started.");
}
