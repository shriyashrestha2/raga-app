import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // Children first, respecting FK constraints.
  await prisma.practiceAgendaItem.deleteMany();
  await prisma.practicePlan.deleteMany();
  await prisma.attendance.deleteMany();
  await prisma.propCostumeAssignment.deleteMany();
  await prisma.propCostumeItem.deleteMany();
  await prisma.fine.deleteMany();
  await prisma.quota.deleteMany();
  await prisma.compApplication.deleteMany();
  await prisma.compScheduleItem.deleteMany();
  await prisma.compFinanceSection.deleteMany();
  await prisma.compProductionSection.deleteMany();
  await prisma.compLogisticsSection.deleteMany();
  await prisma.competition.deleteMany();
  await prisma.choreoReminder.deleteMany();
  await prisma.teamInfo.deleteMany();
  await prisma.rsvp.deleteMany();
  await prisma.video.deleteMany();
  await prisma.update.deleteMany();
  await prisma.practice.deleteMany();
  await prisma.calendarEvent.deleteMany();
  await prisma.user.deleteMany();

  // One demo user per role.
  const [captain, finance, production, logistics, dancer, newbie] = await Promise.all([
    prisma.user.create({
      data: { name: "Priya K.", initials: "PK", role: "CAPTAIN", email: "priya@ruraga.org", year: "Senior" },
    }),
    prisma.user.create({
      data: { name: "Arjun M.", initials: "AM", role: "FINANCE", email: "arjun@ruraga.org", year: "Junior" },
    }),
    prisma.user.create({
      data: { name: "Meera S.", initials: "MS", role: "PRODUCTION", email: "meera@ruraga.org", year: "Junior" },
    }),
    prisma.user.create({
      data: { name: "Rohan V.", initials: "RV", role: "LOGISTICS", email: "rohan@ruraga.org", year: "Sophomore" },
    }),
    prisma.user.create({
      data: { name: "Sam D.", initials: "SD", role: "DANCER", email: "sam@ruraga.org", year: "Sophomore" },
    }),
    prisma.user.create({
      data: { name: "Jordan T.", initials: "JT", role: "NEWBIE", email: "jordan@ruraga.org", year: "Freshman" },
    }),
  ]);

  await prisma.update.createMany({
    data: [
      {
        authorId: captain.id,
        tag: "ANNOUNCEMENT",
        content:
          "We got the stage slot! Performance confirmed for Oct 18 at Rutgers Day. Full run-through this Saturday — everyone must attend.",
        pinned: true,
      },
      {
        authorId: captain.id,
        tag: "CHOREO_NOTES",
        content:
          "After reviewing Sunday's video: formations in Set 3 are off. Left side — hold 2 counts longer before the sweep. Drilling this Saturday.",
      },
      {
        authorId: production.id,
        tag: "COSTUME_LOGISTICS",
        content:
          "Costume reminder: boys wear all black (no logos), girls wear white kurta + red dupatta. Bring both for Oct 5 AV day.",
      },
      {
        authorId: finance.id,
        tag: "ANNOUNCEMENT",
        content: "Finance chairs: Q4 dues reconciliation is due before the Oct 14 budget review. Send me your set totals.",
        audienceRole: "FINANCE",
      },
      {
        authorId: production.id,
        tag: "ANNOUNCEMENT",
        content: "Production: costume fitting slots for Oct 16 are up in the shared sheet — claim yours by Wednesday.",
        audienceRole: "PRODUCTION",
      },
      {
        authorId: logistics.id,
        tag: "ANNOUNCEMENT",
        content: "Logistics: travel packet for Rutgers Day needs everyone's emergency contact confirmed by Friday.",
        audienceRole: "LOGISTICS",
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
        { user: dancer, response: "NO" as const, reason: "Family commitment out of town" },
        { user: newbie, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-09T19:00:00-04:00"),
      location: "College Ave Gym, Studio A",
      focus: "Set 3 Formation Drill",
      reminder: null,
      rsvps: [
        { user: dancer, response: "YES" as const },
        { user: newbie, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-12T13:00:00-04:00"),
      location: "Livingston Rec Center, Studio B",
      focus: "Sets 1–3 Polish + Transitions",
      reminder: null,
      rsvps: [{ user: dancer, response: "NO" as const, reason: "Midterm exam conflict" }],
    },
    {
      date: new Date("2026-10-16T18:00:00-04:00"),
      location: "College Ave Gym, Studio A",
      focus: "Final Dress Rehearsal",
      reminder: null,
      rsvps: [],
    },
  ];

  const createdPractices: Awaited<ReturnType<typeof prisma.practice.create>>[] = [];
  for (const p of practiceData) {
    const practice = await prisma.practice.create({
      data: { date: p.date, location: p.location, focus: p.focus, reminder: p.reminder },
    });
    createdPractices.push(practice);
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
        competition: "Rutgers Day",
        date: new Date("2026-10-01"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=480&h=270&fit=crop&auto=format",
        duration: "4:22",
        uploadedById: production.id,
      },
      {
        title: "Full Run – Sep 28 Practice",
        set: "Full Run",
        competition: "Rutgers Day",
        date: new Date("2026-09-28"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1547153760-18fc86324498?w=480&h=270&fit=crop&auto=format",
        duration: "9:08",
        uploadedById: captain.id,
      },
      {
        title: "Set 3 – Formation Sweep Reference",
        set: "Set 3",
        date: new Date("2026-09-25"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=480&h=270&fit=crop&auto=format",
        duration: "2:45",
        uploadedById: captain.id,
      },
      {
        title: "Set 2 – Arm Isolation Timing",
        set: "Set 2",
        date: new Date("2026-09-20"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1518611012118-696072aa579a?w=480&h=270&fit=crop&auto=format",
        duration: "3:11",
        uploadedById: dancer.id,
      },
      {
        title: "Full Run – Sep 14 Practice",
        set: "Full Run",
        date: new Date("2026-09-14"),
        url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnail: "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=480&h=270&fit=crop&auto=format",
        duration: "8:54",
        uploadedById: production.id,
      },
    ],
  });

  const calendarEventData: { date: Date; category: "FINANCE" | "PRACTICE" | "PRODUCTION" | "SOCIAL" | "PERFORMANCE" | "LOGISTICS"; label: string; createdById?: string }[] = [
    { date: new Date("2026-10-02"), category: "FINANCE", label: "Budget meeting", createdById: finance.id },
    { date: new Date("2026-10-05"), category: "PRACTICE", label: "AV Day" },
    { date: new Date("2026-10-05"), category: "PRODUCTION", label: "Video shoot", createdById: production.id },
    { date: new Date("2026-10-09"), category: "PRACTICE", label: "Formation drill" },
    { date: new Date("2026-10-12"), category: "SOCIAL", label: "Team dinner" },
    { date: new Date("2026-10-12"), category: "PRACTICE", label: "Full run" },
    { date: new Date("2026-10-14"), category: "FINANCE", label: "Dues deadline", createdById: finance.id },
    { date: new Date("2026-10-16"), category: "PRODUCTION", label: "Costume fitting", createdById: production.id },
    { date: new Date("2026-10-16"), category: "PRACTICE", label: "Dress rehearsal" },
    { date: new Date("2026-10-17"), category: "LOGISTICS", label: "Travel + carpool confirmation", createdById: logistics.id },
    { date: new Date("2026-10-18"), category: "PERFORMANCE", label: "Rutgers Day show" },
    { date: new Date("2026-10-20"), category: "SOCIAL", label: "Post-show hangout" },
    { date: new Date("2026-10-23"), category: "PRODUCTION", label: "Recap video edit", createdById: production.id },
    { date: new Date("2026-10-26"), category: "SOCIAL", label: "Bonding event" },
    { date: new Date("2026-10-28"), category: "FINANCE", label: "Fall budget review", createdById: finance.id },
  ];
  const createdEvents: Awaited<ReturnType<typeof prisma.calendarEvent.create>>[] = [];
  for (const e of calendarEventData) {
    createdEvents.push(await prisma.calendarEvent.create({ data: e }));
  }

  // Real attendance (check-in), distinct from Rsvp intent, on a couple of PRACTICE events.
  const avDayEvent = createdEvents.find((e) => e.label === "AV Day")!;
  await prisma.attendance.createMany({
    data: [
      { eventId: avDayEvent.id, userId: dancer.id, status: "ABSENT", markedById: captain.id, notes: "Excused — travel" },
      { eventId: avDayEvent.id, userId: newbie.id, status: "PRESENT", markedById: captain.id },
    ],
  });

  // Fines: any member can be targeted (incl. Captain), only send/manage access is role-gated.
  await prisma.fine.createMany({
    data: [
      { userId: dancer.id, amountCents: 500, reason: "Missed AV Day without 48hr notice", issuedById: captain.id, status: "UNPAID" },
      { userId: newbie.id, amountCents: 500, reason: "Late to Set 3 drill", issuedById: finance.id, status: "PAID", paidAt: new Date("2026-10-11") },
      { userId: captain.id, amountCents: 1000, reason: "Missed logistics travel-form deadline", issuedById: logistics.id, status: "UNPAID" },
    ],
  });

  await prisma.quota.createMany({
    data: [
      { userId: dancer.id, label: "Fundraising quota", unit: "USD", targetValue: 150, currentValue: 60, createdById: finance.id, dueDate: new Date("2026-11-01") },
      { userId: newbie.id, label: "Fundraising quota", unit: "USD", targetValue: 100, currentValue: 25, createdById: finance.id, dueDate: new Date("2026-11-01") },
      { userId: production.id, label: "Volunteer hours", unit: "hours", targetValue: 10, currentValue: 4, createdById: captain.id },
    ],
  });

  await prisma.compApplication.createMany({
    data: [
      {
        competitionName: "Bollywood America 2026",
        deadline: new Date("2026-11-15"),
        status: "IN_PROGRESS",
        notes: "Packet needs 2 more practice logs before submission.",
        assignedToId: logistics.id,
        createdById: captain.id,
      },
      {
        competitionName: "Nach De Punjab Invitational",
        deadline: new Date("2026-12-01"),
        status: "NOT_STARTED",
        assignedToId: logistics.id,
        createdById: captain.id,
      },
    ],
  });

  const kurta = await prisma.propCostumeItem.create({
    data: {
      name: "White Kurta + Red Dupatta Set",
      category: "COSTUME",
      status: "IN_PROGRESS",
      rentalVendor: "Desi Threads NJ",
      rentalCostCents: 4500,
      rentalDueDate: new Date("2026-10-10"),
      createdById: production.id,
    },
  });
  const dhol = await prisma.propCostumeItem.create({
    data: {
      name: "Performance Dhol",
      category: "PROP",
      status: "READY",
      createdById: production.id,
    },
  });
  await prisma.propCostumeAssignment.createMany({
    data: [
      { itemId: kurta.id, userId: dancer.id, size: "M", task: "Pick up from vendor by Oct 8", status: "PENDING" },
      { itemId: kurta.id, userId: newbie.id, size: "S", task: "Confirm measurements", status: "DONE" },
    ],
  });

  const competition = await prisma.competition.create({
    data: {
      name: "Rutgers Day Showcase",
      date: new Date("2026-10-18"),
      location: "College Avenue Green, Rutgers–New Brunswick",
      financeSection: { create: { budgetCents: 200000, spentCents: 85000, notes: "Costume + travel budget on track." } },
      productionSection: { create: { musicStatus: "Final mix locked", costumeStatus: "Fitting in progress", notes: "Formation blocking finalized for Set 3." } },
      logisticsSection: { create: { travelPlan: "Charter van, 9am departure", lodging: "N/A — day trip", transportationNotes: "Confirm headcount by Oct 15." } },
      scheduleItems: {
        create: [
          { time: new Date("2026-10-18T08:00:00-04:00"), label: "Call time / warmup" },
          { time: new Date("2026-10-18T09:30:00-04:00"), label: "Tech + sound check" },
          { time: new Date("2026-10-18T13:00:00-04:00"), label: "Performance set" },
        ],
      },
    },
  });
  void competition;

  await prisma.teamInfo.create({
    data: { teamName: "RU RAGA", season: "Fall 2026", description: "Rutgers University's premier Bollywood fusion dance team." },
  });

  await prisma.choreoReminder.createMany({
    data: [
      { label: "3 formations still need blocking for Set 3", kind: "FORMATION", createdById: captain.id },
      { label: "2 choreo notes pending review before Saturday", kind: "CHOREO_NOTE", createdById: captain.id },
    ],
  });

  const setThreeDrill = createdPractices[1];
  const plan = await prisma.practicePlan.create({
    data: {
      practiceId: setThreeDrill.id,
      title: "Set 3 Formation Drill — Agenda",
      date: setThreeDrill.date,
      createdById: captain.id,
      agendaItems: {
        create: [
          { order: 1, startOffsetMin: 0, durationMin: 15, label: "Warmup + stretch" },
          { order: 2, startOffsetMin: 15, durationMin: 40, label: "Set 3 formation blocking" },
          { order: 3, startOffsetMin: 55, durationMin: 20, label: "Full run with music" },
        ],
      },
    },
  });
  void plan;

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
