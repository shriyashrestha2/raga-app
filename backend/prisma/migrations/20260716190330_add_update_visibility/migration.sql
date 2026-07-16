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
    CONSTRAINT "Update_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Update" ("audienceRole", "authorId", "content", "createdAt", "id", "pinned", "tag", "telegramMessageId") SELECT "audienceRole", "authorId", "content", "createdAt", "id", "pinned", "tag", "telegramMessageId" FROM "Update";
DROP TABLE "Update";
ALTER TABLE "new_Update" RENAME TO "Update";
CREATE UNIQUE INDEX "Update_telegramMessageId_key" ON "Update"("telegramMessageId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
