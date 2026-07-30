-- DropIndex
DROP INDEX "ChatReaction_messageId_userId_emoji_key";

-- CreateIndex
CREATE UNIQUE INDEX "ChatReaction_messageId_userId_key" ON "ChatReaction"("messageId", "userId");
