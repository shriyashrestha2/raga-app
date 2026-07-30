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
  await prisma.fineScheduleItem.deleteMany();
  await prisma.fund.deleteMany();
  await prisma.quotaContribution.deleteMany();
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
  await prisma.reminderRsvp.deleteMany();
  await prisma.reminderTaskCompletion.deleteMany();
  await prisma.reminder.deleteMany();
  await prisma.calendarEvent.deleteMany();
  await prisma.chatReaction.deleteMany();
  await prisma.chatAttachment.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.user.deleteMany();

  // One demo user per role.
  const [captain, finance, production, logistics, pr, returner, newbie] = await Promise.all([
    prisma.user.create({
      data: { name: "Eesan", initials: "EE", role: "CAPTAIN", email: "eesan@ruraga.org", year: "Senior" },
    }),
    prisma.user.create({
      data: { name: "Harshil", initials: "HA", role: "FINANCE", email: "harshil@ruraga.org", year: "Junior" },
    }),
    prisma.user.create({
      data: { name: "Hemal", initials: "HE", role: "PRODUCTION", email: "hemal@ruraga.org", year: "Junior" },
    }),
    prisma.user.create({
      data: { name: "Shivani", initials: "SH", role: "LOGISTICS", email: "shivani@ruraga.org", year: "Sophomore" },
    }),
    prisma.user.create({
      data: { name: "Siya", initials: "SI", role: "PR", email: "siya@ruraga.org", year: "Sophomore" },
    }),
    prisma.user.create({
      data: { name: "Krish", initials: "KR", role: "RETURNER", email: "krish@ruraga.org", year: "Sophomore" },
    }),
    prisma.user.create({
      data: { name: "Karan", initials: "KA", role: "NEWBIE", email: "karan@ruraga.org", year: "Freshman" },
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
        { user: returner, response: "NO" as const, reason: "Family commitment out of town" },
        { user: newbie, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-09T19:00:00-04:00"),
      location: "College Ave Gym, Studio A",
      focus: "Set 3 Formation Drill",
      reminder: null,
      rsvps: [
        { user: returner, response: "YES" as const },
        { user: newbie, response: "YES" as const },
      ],
    },
    {
      date: new Date("2026-10-12T13:00:00-04:00"),
      location: "Livingston Rec Center, Studio B",
      focus: "Sets 1–3 Polish + Transitions",
      reminder: null,
      rsvps: [{ user: returner, response: "NO" as const, reason: "Midterm exam conflict" }],
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

  // No seeded videos: real content now comes from in-app uploads (see
  // routes/videos.ts) rather than YouTube placeholder links.

  const calendarEventData: { date: Date; category: "FINANCE" | "PRACTICE" | "CAPTAINS" | "PRODUCTION" | "SOCIAL" | "LOGISTICS"; label: string; createdById?: string }[] = [
    { date: new Date("2026-10-02"), category: "FINANCE", label: "Budget meeting", createdById: finance.id },
    { date: new Date("2026-10-11"), category: "SOCIAL", label: "Instagram takeover post", createdById: pr.id },
    { date: new Date("2026-10-05"), category: "PRACTICE", label: "AV Day" },
    { date: new Date("2026-10-05"), category: "PRODUCTION", label: "Video shoot", createdById: production.id },
    { date: new Date("2026-10-09"), category: "PRACTICE", label: "Formation drill" },
    { date: new Date("2026-10-12"), category: "SOCIAL", label: "Team dinner" },
    { date: new Date("2026-10-12"), category: "PRACTICE", label: "Full run" },
    { date: new Date("2026-10-14"), category: "FINANCE", label: "Dues deadline", createdById: finance.id },
    { date: new Date("2026-10-16"), category: "PRODUCTION", label: "Costume fitting", createdById: production.id },
    { date: new Date("2026-10-16"), category: "PRACTICE", label: "Dress rehearsal" },
    { date: new Date("2026-10-17"), category: "LOGISTICS", label: "Travel + carpool confirmation", createdById: logistics.id },
    { date: new Date("2026-10-18"), category: "CAPTAINS", label: "Rutgers Day show" },
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
      { eventId: avDayEvent.id, userId: returner.id, status: "ABSENT", markedById: captain.id, notes: "Excused — travel" },
      { eventId: avDayEvent.id, userId: newbie.id, status: "PRESENT", markedById: captain.id },
    ],
  });

  // Fines: any member can be targeted (incl. Captain), only send/manage access is role-gated.
  await prisma.fine.createMany({
    data: [
      { userId: returner.id, amountCents: 500, reason: "Missed AV Day without 48hr notice", issuedById: captain.id, status: "UNPAID" },
      { userId: newbie.id, amountCents: 500, reason: "Late to Set 3 drill", issuedById: finance.id, status: "PAID", paidAt: new Date("2026-10-11") },
      { userId: captain.id, amountCents: 1000, reason: "Missed logistics travel-form deadline", issuedById: logistics.id, status: "UNPAID" },
    ],
  });

  await prisma.fund.createMany({
    data: [
      { amountCents: 85000, source: "Fall Bake Sale", dateAdded: new Date("2026-09-12"), createdById: finance.id },
      { amountCents: 150000, source: "Alumni Sponsor — Patel Family", dateAdded: new Date("2026-09-20"), createdById: finance.id },
      { amountCents: 42000, source: "Dining Hall Percentage Night", dateAdded: new Date("2026-10-01"), createdById: finance.id },
      { amountCents: 60000, source: "Member Dues", dateAdded: new Date("2026-10-08"), createdById: finance.id },
      { amountCents: 22500, source: "Instagram Fundraiser Post", dateAdded: new Date("2026-10-15"), createdById: finance.id },
    ],
  });

  // Fine schedule: the team's standard offense list. Four offenses don't
  // have one fixed dollar figure (Summer video scales by days late, Props
  // productivity isn't finalized, both Concessions fines depend on an
  // external Gourmet Dining charge) — those store a plain-text `description`
  // of the rule instead of `amountCents`, which signals the client to leave
  // the new-fine Amount field blank rather than auto-filling it.
  const fineScheduleData: { offense: string; amountCents?: number; description?: string }[] = [
    { offense: "Late to Practice", amountCents: 500 },
    { offense: "No Show to Practice", amountCents: 1000 },
    { offense: "Not Submitting Practice Video (Winter)", amountCents: 4000 },
    {
      offense: "Not Submitting Practice Video on Time (Summer)",
      description: "$10 base fine, plus $5 for each additional day late",
    },
    { offense: "Late to Props", amountCents: 500 },
    { offense: "No Show to Props", amountCents: 1000 },
    {
      offense: "Significant Lack of Productivity During Props",
      description: "Amount not yet finalized — flag for admin review before enforcing",
    },
    { offense: "Late to a Fundraiser", amountCents: 500 },
    { offense: "No Show to a Fundraiser", amountCents: 2000 },
    { offense: "Late to Concessions", description: "Fine amount set by Gourmet Dining, not fixed" },
    {
      offense: "No Show to Concessions",
      description: "$60, or the fine amount set by Gourmet Dining, whichever applies",
    },
    { offense: "Late to Photoshoot", amountCents: 500 },
    { offense: "Late to a Social Event", amountCents: 500 },
    { offense: "No Show to a Social Event", amountCents: 2000 },
    { offense: "Missed or Late Social Media Repost", amountCents: 500 },
    { offense: "Late Response to a Poll or Task", amountCents: 500 },
    { offense: "Missed Reminder", amountCents: 500 },
    { offense: "Failure to Keep Information Up to Date", amountCents: 500 },
    { offense: "Missed Deadline", amountCents: 500 },
    { offense: "Failure to Enforce a Fine Within 48 Hours", amountCents: 500 },
    { offense: "Confidentiality Breach", amountCents: 1500 },
  ];
  await prisma.fineScheduleItem.createMany({
    data: fineScheduleData.map((item, index) => ({
      offense: item.offense,
      amountCents: item.amountCents ?? null,
      description: item.description ?? null,
      order: index,
    })),
  });

  // currentValue is derived from contributions (see routes/quotas.ts), so
  // each seeded quota's contributions are created to sum to its currentValue.
  const quotaSeeds: {
    userId: string;
    label: string;
    unit: string;
    targetValue: number;
    createdById: string;
    dueDate?: Date;
    contributions: { event: string; amount: number }[];
  }[] = [
    {
      userId: returner.id,
      label: "Fundraising quota",
      unit: "USD",
      targetValue: 150,
      createdById: finance.id,
      dueDate: new Date("2026-11-01"),
      contributions: [
        { event: "Bake Sale table shift", amount: 35 },
        { event: "Dues installment", amount: 25 },
      ],
    },
    {
      userId: newbie.id,
      label: "Fundraising quota",
      unit: "USD",
      targetValue: 100,
      createdById: finance.id,
      dueDate: new Date("2026-11-01"),
      contributions: [{ event: "Instagram fundraiser shoutout", amount: 25 }],
    },
    {
      userId: production.id,
      label: "Volunteer hours",
      unit: "hours",
      targetValue: 10,
      createdById: captain.id,
      contributions: [{ event: "Costume fitting setup", amount: 4 }],
    },
  ];
  for (const q of quotaSeeds) {
    const currentValue = q.contributions.reduce((sum, c) => sum + c.amount, 0);
    await prisma.quota.create({
      data: {
        userId: q.userId,
        label: q.label,
        unit: q.unit,
        targetValue: q.targetValue,
        currentValue,
        createdById: q.createdById,
        dueDate: q.dueDate,
        contributions: {
          create: q.contributions.map((c) => ({ event: c.event, amount: c.amount, createdById: q.createdById })),
        },
      },
    });
  }

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
      { itemId: kurta.id, userId: returner.id, size: "M", task: "Pick up from vendor by Oct 8", status: "PENDING" },
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

  const remindersData: {
    title: string;
    description?: string;
    date: Date;
    category: "FINANCE" | "PRACTICE" | "CAPTAINS" | "PRODUCTION" | "SOCIAL" | "LOGISTICS";
    type: "RSVP" | "TASK";
    createdById: string;
  }[] = [
    {
      title: "Dues payment plan meeting",
      description: "Optional info session for anyone who wants to split dues into installments.",
      date: new Date("2026-10-06T18:00:00-04:00"),
      category: "FINANCE",
      type: "RSVP",
      createdById: finance.id,
    },
    {
      title: "Submit costume measurements",
      description: "Needed before the Oct 16 fitting so orders go out on time.",
      date: new Date("2026-10-08T23:59:00-04:00"),
      category: "PRODUCTION",
      type: "TASK",
      createdById: production.id,
    },
    {
      title: "Confirm carpool signup",
      description: "Sign up for a ride or offer one for the Oct 18 show.",
      date: new Date("2026-10-10T23:59:00-04:00"),
      category: "LOGISTICS",
      type: "TASK",
      createdById: logistics.id,
    },
    {
      title: "Team bonding potluck — bringing food?",
      description: "Let us know if you're signing up for a dish so we don't end up with five bags of chips.",
      date: new Date("2026-10-26T17:00:00-04:00"),
      category: "SOCIAL",
      type: "RSVP",
      createdById: pr.id,
    },
    {
      title: "Learn the new 8-count for Set 2",
      description: "Review Meera's breakdown video before Wednesday's drill.",
      date: new Date("2026-10-08T20:00:00-04:00"),
      category: "PRACTICE",
      type: "TASK",
      createdById: captain.id,
    },
    {
      title: "Attending the leadership sync?",
      date: new Date("2026-10-13T19:00:00-04:00"),
      category: "CAPTAINS",
      type: "RSVP",
      createdById: captain.id,
    },
  ];

  const createdReminders = await Promise.all(
    remindersData.map((r) => prisma.reminder.create({ data: r }))
  );

  await prisma.reminderRsvp.create({
    data: { reminderId: createdReminders[0].id, userId: returner.id, response: "YES" },
  });
  await prisma.reminderTaskCompletion.create({
    data: { reminderId: createdReminders[1].id, userId: returner.id },
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
