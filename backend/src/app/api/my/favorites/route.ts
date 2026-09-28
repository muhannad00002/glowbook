import { z } from "zod";
import { db } from "@/lib/db";
import { notFound, ok, parseBody, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { salonCardSelect } from "@/server/dto";

export const GET = route(async (req) => {
  const user = await requireUser(req);
  const rows = await db.favorite.findMany({
    where: { userId: user.id, salon: { isPublished: true } },
    select: { createdAt: true, salon: { select: salonCardSelect } },
    orderBy: { createdAt: "desc" },
  });
  return rows.map((r) => ({ ...r.salon, isFavorite: true }));
});

export const POST = route(async (req) => {
  const user = await requireUser(req);
  const { salonId } = await parseBody(req, z.object({ salonId: z.string().uuid() }));
  const salon = await db.salon.findFirst({ where: { id: salonId, isPublished: true }, select: { id: true } });
  if (!salon) throw notFound("Salon not found.");
  await db.favorite.upsert({
    where: { userId_salonId: { userId: user.id, salonId } },
    create: { userId: user.id, salonId },
    update: {},
  });
  return ok({ salonId, isFavorite: true }, "Saved to favourites 💕", 201);
});
