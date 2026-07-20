-- CreateTable
CREATE TABLE "QuotaContribution" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "quotaId" TEXT NOT NULL,
    "event" TEXT NOT NULL,
    "amount" REAL NOT NULL,
    "createdById" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "QuotaContribution_quotaId_fkey" FOREIGN KEY ("quotaId") REFERENCES "Quota" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "QuotaContribution_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
