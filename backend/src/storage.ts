import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

// Abstraction over "where uploaded files live" so routes never depend on a
// specific backend. LocalDiskStorage is the only implementation today (no
// cloud credentials configured for this project yet); swapping to an
// S3-compatible bucket later means writing a new class that implements
// these same interfaces and changing the exports below — no route or
// schema changes required.
export interface UploadedFile {
  buffer: Buffer;
  originalName: string;
  mimeType: string;
}

async function saveToDisk(subdir: string, file: UploadedFile): Promise<{ url: string }> {
  const dir = path.join(process.cwd(), "uploads", subdir);
  await mkdir(dir, { recursive: true });
  const ext = path.extname(file.originalName) || guessExtension(file.mimeType);
  const filename = `${randomUUID()}${ext}`;
  await writeFile(path.join(dir, filename), file.buffer);
  return { url: `/uploads/${subdir}/${filename}` };
}

function guessExtension(mimeType: string): string {
  const subtype = mimeType.split("/")[1];
  return subtype ? `.${subtype}` : "";
}

export interface VideoFile extends UploadedFile {}

export interface VideoStorage {
  save(file: VideoFile): Promise<{ url: string }>;
}

class LocalDiskVideoStorage implements VideoStorage {
  save(file: VideoFile): Promise<{ url: string }> {
    return saveToDisk("videos", file);
  }
}

export const videoStorage: VideoStorage = new LocalDiskVideoStorage();

export interface ChatAttachmentStorage {
  save(file: UploadedFile): Promise<{ url: string }>;
}

class LocalDiskChatAttachmentStorage implements ChatAttachmentStorage {
  save(file: UploadedFile): Promise<{ url: string }> {
    return saveToDisk("chat", file);
  }
}

export const chatAttachmentStorage: ChatAttachmentStorage = new LocalDiskChatAttachmentStorage();
