import { z } from "zod";
import { db } from "@/lib/db";
import { conflict, ok, parseBody, parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { dateColumn } from "@/lib/time";
import { customerListSelect } from "@/server/dto";
import { audit } from "@/server/audit";
import { customerInput } from "@/server/validation";
import type { Prisma } from "@/generated/prisma/client";

const querySchema = z.object({
  q: z.string().trim().max(80).optional(),
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, querySchema);
  const where: Prisma.CustomerWhereInput = { salonId: ctx.salonId };
  // An artist only sees clients she has worked with.
  if (ctx.role === "STAFF") where.bookings = { some: { staffId: ctx.staffId! } };
  if (q.q) {
    const digits = q.q.replace(/\D/g, "");
    where.OR = [
      { name: { contains: q.q, mode: "insensitive" } },
      { email: { contains: q.q, mode: "insensitive" } },
      ...(digits.length >= 3 ? [{ phone: { contains: digits } }] : []),
    ];
  }

  const rows = await db.customer.findMany({
    where,
    select: {
      ...customerListSelect,
      bookings: {
        where: { status: { notIn: ["CANCELLED"] } },
        select: { startTime: true, status: true },
        orderBy: { startTime: "desc" },
        take: 1,
      },
      _count: { select: { bookings: true } },
    },
    orderBy: [{ updatedAt: "desc" }],
    take: q.limit + 1,
    ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
  });

  const ids = rows.slice(0, q.limit).map((r) => r.id);
  const spend = await db.payment.groupBy({
    by: ["customerId"],
    where: { salonId: ctx.salonId, customerId: { in: ids }, status: "PAID", kind: { not: "REFUND" } },
    _sum: { amountBaisa: true },
  });
  const spendMap = new Map(spend.map((s) => [s.customerId, s._sum.amountBaisa ?? 0]));

  return {
    items: rows.slice(0, q.limit).map(({ bookings, _count, ...c }) => ({
      ...c,
      bookingCount: _count.bookings,
      lastBookingAt: bookings[0]?.startTime ?? null,
      totalSpentBaisa: spendMap.get(c.id) ?? 0,
    })),
    nextCursor: rows.length > q.limit ? rows[q.limit - 1].id : null,
  };
});

export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const body = await parseBody(req, customerInput);
  if (body.phone) {
    const existing = await db.customer.findUnique({ where: { salonId_phone: { salonId: ctx.salonId, phone: body.phone } } });
    if (existing) throw conflict("A client with this phone number already exists.", { customerId: existing.id });
  }
  if (body.preferredStaffId) {
    const s = await db.staff.findFirst({ where: { id: body.preferredStaffId, salonId: ctx.salonId } });
    if (!s) throw conflict("Staff member not found.");
  }
  const customer = await db.customer.create({
    data: {
      ...body,
      birthday: body.birthday ? dateColumn(body.birthday) : null,
      salonId: ctx.salonId,
      source: "ADMIN",
    },
    select: customerListSelect,
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "customer.created", entityType: "Customer", entityId: customer.id });
  return ok(customer, "Client added 💕", 201);
});
