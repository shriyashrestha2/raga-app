-- CreateTable
CREATE TABLE "ReminderTopic" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ReminderTopic_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Reminder" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "topicId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "date" DATETIME NOT NULL,
    "addedToCalendar" BOOLEAN NOT NULL DEFAULT false,
    "calendarEventId" TEXT,
    "ownerId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "Reminder_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "ReminderTopic" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "Reminder_calendarEventId_fkey" FOREIGN KEY ("calendarEventId") REFERENCES "CalendarEvent" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "Reminder_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "ReminderTopic_ownerId_name_key" ON "ReminderTopic"("ownerId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Reminder_calendarEventId_key" ON "Reminder"("calendarEventId");
