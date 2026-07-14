import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  await prisma.rsvp.deleteMany();
  await prisma.video.deleteMany();
  await prisma.update.deleteMany();
  await prisma.practice.deleteMany();
  await prisma.calendarEvent.deleteMany();
  await prisma.user.deleteMany();

  const [priya, arjun, meera, dancer1, dancer2] = await Promise.all([
    prisma.user.create({ data: { name: "Priya K.", initials: "PK", role: "CAPTAIN" } }),
    prisma.user.create({ data: { name: "Arjun M.", initials: "AM", role: "CAPTAIN" } }),
    prisma.user.create({ data: { name: "Meera S.", initials: "MS", role: "CAPTAIN" } }),
    prisma.user.create({ data: { name: "Sam D.", initials: "SD", role: "DANCER" } }),
    prisma.user.create({ data: { name: "Jordan T.", initials: "JT", role: "DANCER" } }),
  ]);

  await prisma.update.createMany({
    data: [
      {
        authorId: priya.id,
        tag: "ANNOUNCEMENT",
        content:
          "We got the stage slot! Performance confirmed for Oct 18 at Rutgers Day. Full run-through this Saturday — everyone must attend.",
        pinned: true,
      },
      {
        authorId: arjun.id,
        tag: "CHOREO_NOTES",
        content:
          "After reviewing Sunday's video: formations in Set 3 are off. Left side — hold 2 counts longer before the sweep. Drilling this Saturday.",
      },
      {
        authorId: priya.id,
        tag: "COSTUME_LOGISTICS",
        content:
          "Costume reminder: boys wear all black (no logos), girls wear white kurta + red dupatta. Bring both for Oct 5 AV day.",
      },
      {
        authorId: meera.id,
        tag: "CHOREO_NOTES",
        content: "Breakdown for the new 8-count in Set 1: step-touch-step on beats 1–3, then isolate the arms on 5–6.",
      },
    ],
  });

  const practiceData = [
    {
      date: new Date("2026-10-05T14:00:00-04:00"),
      location: "Livingston Rec Center, Studio B",
      focus: "AV Day — Full Run-Through",
      reminder: "Boys wear black, girls wear white kurta + red dupatta",
      rsvps: [
        { user: dancer1, response: "NO" as const, reason: "Family commitment out of town" },
        { user: dancer2, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-09T19:00:00-04:00"),
      location: "College Ave Gym, Studio A",
      focus: "Set 3 Formation Drill",
      reminder: null,
      rsvps: [
        { user: dancer1, response: "YES" as const },
        { user: dancer2, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-12T13:00:00-04:00"),
      location: "Livingston Rec Center, Studio B",
      focus: "Sets 1–3 Polish + Transitions",
      reminder: null,
      rsvps: [{ user: dancer1, response: "NO" as const, reason: "Midterm exam conflict" }],
    },
    {
      date: new Date("2026-10-16T18:00:00-04:00"),
      location: "College Ave Gym, Studio A",
      focus: "Final Dress Rehearsal",
      reminder: null,
      rsvps: [],
    },
  ];

  for (const p of practiceData) {
    const practice = await prisma.practice.create({
      data: { date: p.date, location: p.location, focus: p.focus, reminder: p.reminder },
    });
    for (const r of p.rsvps) {
      await prisma.rsvp.create({
        data: {
          practiceId: practice.id,
          userId: r.user.id,
          response: r.response,
          reason: "reason" in r ? r.reason : null,
        },
      });
    }
  }

  await prisma.video.createMany({
    data: [
      {
        title: "Set 1 – New Intro Count Breakdown",
        set: "Set 1",
        date: new Date("2026-10-01"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=480&h=270&fit=crop&auto=format",
        duration: "4:22",
        uploadedById: meera.id,
      },
      {
        title: "Full Run – Sep 28 Practice",
        set: "Full Run",
        date: new Date("2026-09-28"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1547153760-18fc86324498?w=480&h=270&fit=crop&auto=format",
        duration: "9:08",
        uploadedById: arjun.id,
      },
      {
        title: "Set 3 – Formation Sweep Reference",
        set: "Set 3",
        date: new Date("2026-09-25"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=480&h=270&fit=crop&auto=format",
        duration: "2:45",
        uploadedById: priya.id,
      },
      {
        title: "Set 2 – Arm Isolation Timing",
        set: "Set 2",
        date: new Date("2026-09-20"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1518611012118-696072aa579a?w=480&h=270&fit=crop&auto=format",
        duration: "3:11",
        uploadedById: arjun.id,
      },
      {
        title: "Full Run – Sep 14 Practice",
        set: "Full Run",
        date: new Date("2026-09-14"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=480&h=270&fit=crop&auto=format",
        duration: "8:54",
        uploadedById: meera.id,
      },
    ],
  });

  await prisma.calendarEvent.createMany({
    data: [
      { date: new Date("2026-10-02"), category: "FINANCE", label: "Budget meeting" },
      { date: new Date("2026-10-05"), category: "PRACTICE", label: "AV Day" },
      { date: new Date("2026-10-05"), category: "PRODUCTION", label: "Video shoot" },
      { date: new Date("2026-10-09"), category: "PRACTICE", label: "Formation drill" },
      { date: new Date("2026-10-12"), category: "SOCIAL", label: "Team dinner" },
      { date: new Date("2026-10-12"), category: "PRACTICE", label: "Full run" },
      { date: new Date("2026-10-14"), category: "FINANCE", label: "Dues deadline" },
      { date: new Date("2026-10-16"), category: "PRODUCTION", label: "Costume fitting" },
      { date: new Date("2026-10-16"), category: "PRACTICE", label: "Dress rehearsal" },
      { date: new Date("2026-10-18"), category: "PERFORMANCE", label: "Rutgers Day show" },
      { date: new Date("2026-10-20"), category: "SOCIAL", label: "Post-show hangout" },
      { date: new Date("2026-10-23"), category: "PRODUCTION", label: "Recap video edit" },
      { date: new Date("2026-10-26"), category: "SOCIAL", label: "Bonding event" },
      { date: new Date("2026-10-28"), category: "FINANCE", label: "Fall budget review" },
    ],
  });

  console.log("Seed complete.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
