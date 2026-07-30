import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import cors from "cors";
import { updatesRouter } from "./routes/updates.js";
import { practicesRouter } from "./routes/practices.js";
import { videosRouter } from "./routes/videos.js";
import { usersRouter } from "./routes/users.js";
import { calendarRouter } from "./routes/calendar.js";
import { meRouter } from "./routes/me.js";
import { attendanceRouter } from "./routes/attendance.js";
import { practicePlannerRouter } from "./routes/practicePlanner.js";
import { choreoRemindersRouter } from "./routes/choreoReminders.js";
import { finesRouter } from "./routes/fines.js";
import { quotasRouter } from "./routes/quotas.js";
import { fundsRouter } from "./routes/funds.js";
import { fineScheduleRouter } from "./routes/fineSchedule.js";
import { propsCostumesRouter } from "./routes/propsCostumes.js";
import { compApplicationsRouter } from "./routes/compApplications.js";
import { competitionsRouter } from "./routes/competitions.js";
import { teamInfoRouter } from "./routes/teamInfo.js";
import { remindersRouter } from "./routes/reminders.js";
import { authRouter } from "./routes/auth.js";
import { chatRouter } from "./routes/chat.js";
import { attachCurrentUser } from "./middleware/currentUser.js";
import { startTelegramBot } from "./telegram/bot.js";
import { startFineReminderScheduler } from "./scheduler.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "../uploads")));
app.use(attachCurrentUser);

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/updates", updatesRouter);
app.use("/practices", practicesRouter);
app.use("/videos", videosRouter);
app.use("/users", usersRouter);
app.use("/calendar", calendarRouter);
app.use("/me", meRouter);
app.use("/attendance", attendanceRouter);
app.use("/practice-plans", practicePlannerRouter);
app.use("/choreo-reminders", choreoRemindersRouter);
app.use("/fines", finesRouter);
app.use("/quotas", quotasRouter);
app.use("/funds", fundsRouter);
app.use("/fine-schedule", fineScheduleRouter);
app.use("/props-costumes", propsCostumesRouter);
app.use("/comp-applications", compApplicationsRouter);
app.use("/competitions", competitionsRouter);
app.use("/team-info", teamInfoRouter);
app.use("/reminders", remindersRouter);
app.use("/auth", authRouter);
app.use("/chat", chatRouter);

const port = Number(process.env.PORT ?? 4000);
app.listen(port, () => {
  console.log(`RU RAGA backend listening on http://localhost:${port}`);
});

startTelegramBot();
startFineReminderScheduler();
