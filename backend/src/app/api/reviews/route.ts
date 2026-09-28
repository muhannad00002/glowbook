import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";

/** All reviews for the salon (team view — full client names, unpublished too). */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const items = await db.review.findMany({
    where: { salonId: ctx.salonId, ...(ctx.role === "STAFF" ? { staffId: ctx.staffId! } : {}) },
    include: {
      customer: { select: { id: true, name: true } },
      staff: { select: { id: true, name: true } },
      booking: { select: { reference: true, startTime: true, service: { select: { name: true } } } },
    },
    orderBy: { createdAt: "desc" },
    take: 200,
  });
  const salon = await db.salon.findUniqueOrThrow({ where: { id: ctx.salonId }, select: { ratingAvg: true, ratingCount: true } });
  const distribution = [5, 4, 3, 2, 1].map((star) => ({ star, count: items.filter((r) => r.rating === star).length }));
  return { items, ratingAvg: salon.ratingAvg, ratingCount: salon.ratingCount, distribution };
});
