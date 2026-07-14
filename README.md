# RU RAGA App

Native iOS companion app for the team, built from `team-app-prd.md` and the
[Figma prototype](https://www.figma.com/make/tD8aEU6htJEYEvPcrAAUBf/Create-clean-UI-prototype).
Sits alongside Telegram as the team's single source of truth for the daily
roundup, practice RSVPs, and the practice video library.

## Structure

- `backend/` — Node.js + TypeScript + Express + Prisma (SQLite for local dev) API.
  Also hosts the (currently disabled) Telegram bot that ingests roundup posts.
- `ios/` — SwiftUI iOS app (XcodeGen-managed project), matching the Figma prototype's
  Roundup / Practice / Videos tabs and maroon RU RAGA branding.

## Quickstart

### 1. Backend

```sh
cd backend
npm install
npm run seed   # populates SQLite with demo data matching the prototype
npm run dev    # starts the API on http://localhost:4000
```

See `backend/README.md` for the full API reference and how to turn on real
Telegram ingestion once you have a bot token.

### 2. iOS app

```sh
cd ios
xcodegen generate   # only needed after project.yml changes, or on first checkout
open RagaApp.xcodeproj
```

Run the `RagaApp` scheme on any iOS 17+ Simulator. The app talks to
`http://localhost:4000` (the Simulator shares the Mac's network stack, so this
works with no extra setup). To run on a physical device instead, change
`APIClient.baseURL` in `ios/RagaApp/Networking/APIClient.swift` to your Mac's
LAN IP.

## Current scope / what's real vs. mocked

- **Practice + RSVP**: fully real — backed by the Express API and SQLite.
  Declining ("No") requires a short reason, per the team's decision on the
  PRD's open question; captains see the full per-dancer breakdown, dancers
  see aggregate counts only.
- **Video library**: fully real — YouTube links + set/song labels, filterable
  by set, stored in the database. In-app upload/recording and timestamped
  comments are still open questions from the PRD and aren't built yet.
- **Roundup**: reads from the database, seeded with sample posts that mirror
  the prototype. Live Telegram ingestion is scaffolded but **disabled by
  default** — there's no bot token yet. See `backend/README.md` to turn it on.
- **Roles**: no login yet. A visible toggle (matching the Figma prototype)
  switches the whole app between the "dancer" and "captain" demo users. Real
  per-user accounts are a follow-up.

## Known follow-ups (from the PRD's open questions)

- Public Telegram channel vs. private group, and the exact captain/hashtag
  filtering rules — needs a real bot + channel to finalize.
- Whether Telegram media (images/video) should also surface in the roundup.
- In-app video recording vs. upload-only; timestamped video comments.
- Push notifications — deferred to post-MVP per the PRD.
- Real accounts/auth to replace the dev role toggle.
