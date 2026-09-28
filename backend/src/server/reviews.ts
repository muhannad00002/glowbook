import { db } from "@/lib/db";

/** Keeps the denormalised rating on Salon in step with published reviews. */
export async function refreshSalonRating(salonId: string) {
  const agg = await db.review.aggregate({
    where: { salonId, isPublished: true },
    _avg: { rating: true },
    _count: { _all: true },
  });
  await db.salon.update({
    where: { id: salonId },
    data: { ratingAvg: Math.round((agg._avg.rating ?? 0) * 10) / 10, ratingCount: agg._count._all },
  });
}
