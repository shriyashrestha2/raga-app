import "dotenv/config";
import express from "express";
import cors from "cors";
import { updatesRouter } from "./routes/updates.js";
import { practicesRouter } from "./routes/practices.js";
import { videosRouter } from "./routes/videos.js";
import { usersRouter } from "./routes/users.js";
import { calendarRouter } from "./routes/calendar.js";
import { startTelegramBot } from "./telegram/bot.js";

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/updates", updatesRouter);
app.use("/practices", practicesRouter);
app.use("/videos", videosRouter);
app.use("/users", usersRouter);
app.use("/calendar", calendarRouter);

const port = Number(process.env.PORT ?? 4000);
app.listen(port, () => {
  console.log(`RU RAGA backend listening on http://localhost:${port}`);
});

startTelegramBot();
