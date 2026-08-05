-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Practice" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "date" DATETIME NOT NULL,
    "location" TEXT NOT NULL,
    "focus" TEXT NOT NULL,
    "reminder" TEXT,
    "kind" TEXT NOT NULL DEFAULT 'PRACTICE',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO "new_Practice" ("createdAt", "date", "focus", "id", "location", "reminder") SELECT "createdAt", "date", "focus", "id", "location", "reminder" FROM "Practice";
DROP TABLE "Practice";
ALTER TABLE "new_Practice" RENAME TO "Practice";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
