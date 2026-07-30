import { prisma } from "./prisma.js";

const DAY_MS = 24 * 60 * 60 * 1000;

// UTC, not server-local time — dueDate/createdAt-for-dedup both need to line
// up with how dueDate itself is stored (a UTC-midnight, date-only value), or
// the "already sent today" / "not yet due" checks below would be off by a
// day for servers running outside UTC.
function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

// Sends one reminder per unpaid fine per calendar day, starting the day
// after it's issued (the issuance notification in fines.ts already covers
// day zero) and stopping once dueDate passes or the fine is paid/waived —
// both handled by this same query, so there's nothing to clean up
// separately. Dedup against relatedFineId + "created today" rather than a
// separate tracking table, since an Update row already carries everything
// needed to answer "did today's reminder for this fine already go out."
export async function sendFineDueReminders(): Promise<void> {
  const today = startOfDay(new Date());

  const fines = await prisma.fine.findMany({
    where: { status: "UNPAID", dueDate: { gte: today } },
  });

  for (const fine of fines) {
    const alreadySentToday = await prisma.update.findFirst({
      where: { relatedFineId: fine.id, createdAt: { gte: today } },
    });
    if (alreadySentToday) continue;

    await prisma.update.create({
      data: {
        authorId: fine.issuedById,
        tag: "FINANCE",
        // dueDate is a UTC-midnight, date-only value — format in UTC so it
        // doesn't shift a day back for servers running west of UTC.
        content: `Reminder: you have an unpaid fine of ${(fine.amountCents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })} (${fine.reason}) due ${fine.dueDate!.toLocaleDateString("en-US", { timeZone: "UTC" })}.`,
        targetUserId: fine.userId,
        relatedFineId: fine.id,
      },
    });
  }
}

// No cron/scheduling library exists in this backend — this is a small
// single-process app, so a plain daily setInterval is enough rather than
// pulling in a new dependency for it.
export function startFineReminderScheduler(): void {
  sendFineDueReminders().catch((err) => console.error("Fine reminder job failed", err));
  setInterval(() => {
    sendFineDueReminders().catch((err) => console.error("Fine reminder job failed", err));
  }, DAY_MS);
}
