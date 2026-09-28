import { z } from "zod";
import { db } from "@/lib/db";
import { notFound, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { refreshSalonRating } from "@/server/reviews";

const schema = z.object({
  reply: z.string().trim().max(1000).nullable().optional(),
  isPublished: z.boolean().optional(),
});

export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, schema);
  const review = await db.review.findFirst({ where: { id, salonId: ctx.salonId } });
  if (!review) throw notFound("Review not found.");
  const updated = await db.review.update({
    where: { id },
    data: {
      ...(body.reply !== undefined ? { reply: body.reply || null, repliedAt: body.reply ? new Date() : null } : {}),
      ...(body.isPublished !== undefined ? { isPublished: body.isPublished } : {}),
    },
  });
  if (body.isPublished !== undefined) await refreshSalonRating(ctx.salonId);
  return updated;
});
