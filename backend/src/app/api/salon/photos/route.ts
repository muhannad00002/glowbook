import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { MAX_PHOTOS, MAX_UPLOAD_BYTES, mediaIdFromUrl, mediaUrl, storeSalonImage } from "@/server/media";
import { audit } from "@/server/audit";

/** Upload a gallery photo (multipart field "file"); it is added to the end of the gallery. */
export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const salon = await db.salon.findUniqueOrThrow({ where: { id: ctx.salonId }, select: { photos: true } });
  if (salon.photos.length >= MAX_PHOTOS) throw badRequest(`The gallery holds up to ${MAX_PHOTOS} photos. Remove one first.`);

  const form = await req.formData().catch(() => null);
  const file = form?.get("file");
  if (!(file instanceof File)) throw badRequest("Choose a photo to upload.");
  if (file.size > MAX_UPLOAD_BYTES) throw badRequest("That photo is too large (4 MB max).");

  const media = await storeSalonImage(ctx.salonId, Buffer.from(await file.arrayBuffer()));
  const url = mediaUrl(req.nextUrl.origin, media.id);
  const updated = await db.salon.update({ where: { id: ctx.salonId }, data: { photos: { push: url } }, select: { photos: true } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "salon.photo.added", entityType: "Salon", entityId: ctx.salonId });
  return ok({ url, photos: updated.photos }, "Photo added ✨", 201);
});

/** Remove a gallery photo: DELETE /api/salon/photos?url=… (our own images are deleted too). */
export const DELETE = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const { url } = parseQuery(req, z.object({ url: z.string().min(1) }));
  const salon = await db.salon.findUniqueOrThrow({ where: { id: ctx.salonId }, select: { photos: true } });
  const updated = await db.salon.update({
    where: { id: ctx.salonId },
    data: { photos: salon.photos.filter((p) => p !== url) },
    select: { photos: true },
  });
  const id = mediaIdFromUrl(url);
  if (id) await db.mediaFile.deleteMany({ where: { id, salonId: ctx.salonId } });
  return ok({ photos: updated.photos }, "Photo removed");
});
