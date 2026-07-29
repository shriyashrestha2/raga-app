import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

// Abstraction over "where uploaded video files live" so the routes never
// depend on a specific backend. LocalDiskStorage is the only implementation
// today (no cloud credentials configured for this project yet); swapping to
// an S3-compatible bucket later means writing a new class that implements
// this same interface and changing the export below — no route or schema
// changes required.
export interface VideoFile {
  buffer: Buffer;
  originalName: string;
  mimeType: string;
}

export interface VideoStorage {
  save(file: VideoFile): Promise<{ url: string }>;
}

const UPLOAD_DIR = path.join(process.cwd(), "uploads", "videos");

class LocalDiskStorage implements VideoStorage {
  async save(file: VideoFile): Promise<{ url: string }> {
    await mkdir(UPLOAD_DIR, { recursive: true });
    const ext = path.extname(file.originalName) || guessExtension(file.mimeType);
    const filename = `${randomUUID()}${ext}`;
    await writeFile(path.join(UPLOAD_DIR, filename), file.buffer);
    return { url: `/uploads/videos/${filename}` };
  }
}

function guessExtension(mimeType: string): string {
  const subtype = mimeType.split("/")[1];
  return subtype ? `.${subtype}` : "";
}

export const videoStorage: VideoStorage = new LocalDiskStorage();
