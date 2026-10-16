import sharp, { type OutputInfo } from "sharp";
import { db } from "@/lib/db";
import { badRequest } from "@/lib/http";

/** Gallery photos per salon. */
export const MAX_PHOTOS = 12;
/** Largest upload accepted (Vercel caps request bodies at ~4.5 MB). */
export const MAX_UPLOAD_BYTES = 4 * 1024 * 1024;

/**
 * Re-encodes an uploaded image as a web-friendly JPEG: honours phone orientation, caps
 * the long edge at 1600px and strips metadata (EXIF/GPS) — so a photo straight from an
 * iPhone ends up ~200 KB and never leaks where it was taken.
 */
export async function storeSalonImage(salonId: string, input: Buffer) {
  let out: { data: Buffer; info: OutputInfo };
  try {
    out = await sharp(input, { failOn: "error" })
      .rotate()
      .resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 80, mozjpeg: true })
      .toBuffer({ resolveWithObject: true });
  } catch {
    throw badRequest("That file isn't an image we can use. Try a JPEG, PNG, HEIC or WebP photo.");
  }
  return db.mediaFile.create({
    data: { salonId, contentType: "image/jpeg", bytes: new Uint8Array(out.data), width: out.info.width, height: out.info.height },
    select: { id: true },
  });
}

/** Public URL of a stored image, on the API's own origin. */
export const mediaUrl = (origin: string, id: string) => `${origin.replace(/\/$/, "")}/api/media/${id}`;

/** The media id inside one of our URLs, or null for an external link. */
export function mediaIdFromUrl(url: string) {
  return /\/api\/media\/([0-9a-f-]{36})(?:$|[?#])/i.exec(url)?.[1] ?? null;
}
