import { z } from "zod";
import { db } from "@/lib/db";
import { notFound, parseQuery, route } from "@/lib/http";
import { publicName, reviewPublicSelect } from "@/server/dto";

const querySchema = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const GET = route(async (req, { id }) => {
  const q = parseQuery(req, querySchema);
  const salon = await db.salon.findFirst({ where: { OR: [{ id }, { slug: id }], isPublished: true }, select: { id: true } });
  if (!salon) throw notFound("Salon not found.");
  const rows = await db.review.findMany({
    where: { salonId: salon.id, isPublished: true },
    select: reviewPublicSelect,
    orderBy: { createdAt: "desc" },
    take: q.limit + 1,
    ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
  });
  return {
    items: rows.slice(0, q.limit).map((r) => ({ ...r, customer: { name: publicName(r.customer.name) } })),
    nextCursor: rows.length > q.limit ? rows[q.limit - 1].id : null,
  };
});
