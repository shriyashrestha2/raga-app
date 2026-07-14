# RU RAGA Backend

Node.js + TypeScript + Express API, using Prisma with SQLite for local dev
(no Docker/Postgres setup required to get running).

## Setup

```sh
npm install
npm run seed    # (re)seeds the SQLite DB with demo data
npm run dev     # http://localhost:4000, auto-restarts on file changes
```

`npm run build && npm start` runs the compiled JS instead of `tsx`.

## Environment variables (`.env`)

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `file:./dev.db` | SQLite file location |
| `PORT` | `4000` | API port |
| `ENABLE_TELEGRAM` | `false` | Flip to `true` once the bot token/chat below are set |
| `TELEGRAM_BOT_TOKEN` | _(empty)_ | From BotFather, see below |
| `TELEGRAM_CHAT_ID` | _(empty)_ | The team channel/group's chat ID |

## API

| Endpoint | Notes |
|---|---|
| `GET /health` | Liveness check |
| `GET /users` | Demo users (stand-in for accounts — see root README) |
| `GET /updates` | Roundup feed, pinned first then newest |
| `GET /practices?userId=&role=` | Practice list with RSVP aggregates; `role=CAPTAIN` also returns a per-dancer `detail` breakdown |
| `POST /practices` | Create a practice `{ date, location, focus, reminder? }` |
| `POST /practices/:id/rsvp` | `{ userId, response: "YES"|"NO", reason? }` — **`reason` is required when `response` is `"NO"`** (400 otherwise) |
| `GET /videos?set=` | Video library, optionally filtered by set/song label |
| `POST /videos` | Add a YouTube link `{ title, set, url, uploadedById, ... }` |
| `GET /calendar` | Team calendar events (for the Roundup tab's mini calendar) |

## Enabling real Telegram ingestion

The bot (in `src/telegram/bot.ts`, using [grammy](https://grammy.dev)) is
scaffolded but **off by default** since there's no bot token yet. To turn it on:

1. **Create the bot.** Message [@BotFather](https://t.me/BotFather) on Telegram,
   send `/newbot`, and follow the prompts. You'll get back a token like
   `123456:ABC-DEF...` — put that in `TELEGRAM_BOT_TOKEN`.
2. **Add the bot to your team channel/group** as a member (a private group
   works out of the box; a channel needs the bot added as an **admin** so it
   can read posts — this is the PRD's open question #1, public channel vs.
   private group).
3. **Get the chat ID.** Send a message in the channel/group, then visit
   `https://api.telegram.org/bot<TOKEN>/getUpdates` in a browser — the JSON
   response includes a `chat.id` (negative for groups/channels). Put that in
   `TELEGRAM_CHAT_ID`.
4. Set `ENABLE_TELEGRAM=true` in `.env` and restart `npm run dev`.

Once enabled, the bot filters incoming messages per the PRD (§4.1): only
posts from a user whose seeded role is `CAPTAIN`, or any message containing
`#update`, get mirrored into the `Update` table. `#costume`/`#logistics` and
`#choreo` hashtags route to those categories; everything else defaults to
`Announcement`. Unknown senders are auto-created as `DANCER` users the first
time they post a `#update`-tagged message.
