import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, parseQuery, route } from "@/lib/http";
import { optionalUser, requireUser } from "@/lib/auth/context";
import { salonCardSelect } from "@/server/dto";
import { createSalonForOwner } from "@/server/auth-service";
import { audit } from "@/server/audit";
import type { Prisma } from "@/generated/prisma/client";

const querySchema = z.object({
  q: z.string().trim().max(80).optional(),
  category: z.enum(["MAKEUP", "BEAUTY", "HAIR", "STUDIO", "ARTIST"]).optional(),
  city: z.string().trim().max(60).optional(),
  favorites: z.enum(["true", "false"]).optional(),
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

/** Public salon discovery. */
export const GET = route(async (req) => {
  const q = parseQuery(req, querySchema);
  const user = await optionalUser(req);
  const where: Prisma.SalonWhereInput = { isPublished: true };
  if (q.category) where.category = q.category;
  if (q.city) where.city = { equals: q.city, mode: "insensitive" };
  if (q.q) {
    where.OR = [
      { name: { contains: q.q, mode: "insensitive" } },
      { nameAr: { contains: q.q } },
      { city: { contains: q.q, mode: "insensitive" } },
      { services: { some: { name: { contains: q.q, mode: "insensitive" }, isActive: true, deletedAt: null } } },
    ];
  }
  if (q.favorites === "true" && user) where.favorites = { some: { userId: user.id } };

  const rows = await db.salon.findMany({
    where,
    select: {
      ...salonCardSelect,
      services: {
        where: { isActive: true, deletedAt: null },
        select: { priceBaisa: true },
        orderBy: { priceBaisa: "asc" },
        take: 1,
      },
    },
    orderBy: [{ ratingCount: "desc" }, { createdAt: "asc" }],
    take: q.limit + 1,
    ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
  });

  const favoriteIds = user
    ? new Set((await db.favorite.findMany({ where: { userId: user.id }, select: { salonId: true } })).map((f) => f.salonId))
    : new Set<string>();

  const items = rows.slice(0, q.limit).map(({ services, ...s }) => ({
    ...s,
    fromPriceBaisa: services[0]?.priceBaisa ?? null,
    isFavorite: favoriteIds.has(s.id),
  }));
  return { items, nextCursor: rows.length > q.limit ? rows[q.limit - 1].id : null };
});

const createSchema = z.object({
  name: z.string().trim().min(2).max(80),
  phone: z.string().trim().max(20).optional(),
  city: z.string().trim().max(60).optional(),
  category: z.enum(["MAKEUP", "BEAUTY", "HAIR", "STUDIO", "ARTIST"]).default("MAKEUP"),
});

/** An existing account opens (another) salon and becomes its owner. */
export const POST = route(async (req) => {
  const user = await requireUser(req);
  const body = await parseBody(req, createSchema);
  const salon = await createSalonForOwner({ ownerId: user.id, salonName: body.name, phone: body.phone, city: body.city, category: body.category });
  await audit({ req, salonId: salon.id, userId: user.id, action: "salon.created", entityType: "Salon", entityId: salon.id });
  return ok(salon, "Your salon is ready ✨", 201);
});
