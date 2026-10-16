import { db } from "@/lib/db";
import { notFound, route } from "@/lib/http";

/** Public image bytes. Images never change (a replacement gets a new id), so cache forever. */
export const GET = route(async (_req, { id }) => {
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw notFound();
  const file = await db.mediaFile.findUnique({ where: { id }, select: { bytes: true, contentType: true } });
  if (!file) throw notFound("Image not found.");
  return new Response(new Uint8Array(file.bytes), {
    headers: {
      "Content-Type": file.contentType,
      "Cache-Control": "public, max-age=31536000, immutable",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
