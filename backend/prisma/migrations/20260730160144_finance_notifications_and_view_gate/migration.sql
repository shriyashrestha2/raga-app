-- AlterTable
ALTER TABLE "Fine" ADD COLUMN "dueDate" DATETIME;

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Update" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "authorId" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "pinned" BOOLEAN NOT NULL DEFAULT false,
    "audienceRole" TEXT,
    "visibleToRoles" TEXT NOT NULL DEFAULT '',
    "telegramMessageId" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "targetUserId" TEXT,
    "relatedFineId" TEXT,
    CONSTRAINT "Update_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Update_targetUserId_fkey" FOREIGN KEY ("targetUserId") REFERENCES "User" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "Update_relatedFineId_fkey" FOREIGN KEY ("relatedFineId") REFERENCES "Fine" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_Update" ("audienceRole", "authorId", "content", "createdAt", "id", "pinned", "tag", "telegramMessageId", "visibleToRoles") SELECT "audienceRole", "authorId", "content", "createdAt", "id", "pinned", "tag", "telegramMessageId", "visibleToRoles" FROM "Update";
DROP TABLE "Update";
ALTER TABLE "new_Update" RENAME TO "Update";
CREATE UNIQUE INDEX "Update_telegramMessageId_key" ON "Update"("telegramMessageId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
