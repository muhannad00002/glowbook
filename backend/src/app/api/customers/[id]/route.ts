import { db } from "@/lib/db";
import { conflict, forbidden, notFound, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { dateColumn, dateColumnToString } from "@/lib/time";
import { bookingSalonSelect } from "@/server/dto";
import { customerInput } from "@/server/validation";
import { audit } from "@/server/audit";

/** Full CRM profile: details, private notes, stats, history and upcoming visit. */
export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  const customer = await db.customer.findFirst({
    where: { id, salonId: ctx.salonId },
    include: { preferredStaff: { select: { id: true, name: true, nameAr: true, color: true } } },
  });
  if (!customer) throw notFound("Client not found.");
  if (ctx.role === "STAFF") {
    const worked = await db.booking.count({ where: { customerId: id, staffId: ctx.staffId! } });
    if (!worked) throw forbidden();
  }

  const [bookings, spent, refunded] = await Promise.all([
    db.booking.findMany({
      where: { customerId: id, salonId: ctx.salonId },
      select: bookingSalonSelect,
      orderBy: { startTime: "desc" },
      take: 50,
    }),
    db.payment.aggregate({
      where: { customerId: id, salonId: ctx.salonId, status: "PAID", kind: { not: "REFUND" } },
      _sum: { amountBaisa: true },
    }),
    db.payment.aggregate({
      where: { customerId: id, salonId: ctx.salonId, status: "PAID", kind: "REFUND" },
      _sum: { amountBaisa: true },
    }),
  ]);

  const now = Date.now();
  const past = bookings.filter((b) => b.status === "COMPLETED");
  const upcoming = bookings
    .filter((b) => b.startTime.getTime() >= now && ["PENDING", "CONFIRMED"].includes(b.status))
    .sort((a, b) => a.startTime.getTime() - b.startTime.getTime());

  // Favourite service / artist from completed visits.
  const tally = (key: (b: (typeof past)[number]) => string) => {
    const m = new Map<string, number>();
    for (const b of past) m.set(key(b), (m.get(key(b)) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  };

  return {
    ...customer,
    birthday: customer.birthday ? dateColumnToString(customer.birthday) : null,
    stats: {
      totalSpentBaisa: (spent._sum.amountBaisa ?? 0) - (refunded._sum.amountBaisa ?? 0),
      visits: past.length,
      cancellations: bookings.filter((b) => b.status === "CANCELLED").length,
      noShows: bookings.filter((b) => b.status === "NO_SHOW").length,
      lastVisitAt: past[0]?.startTime ?? null,
      favoriteService: tally((b) => b.service.name),
      favoriteStaff: tally((b) => b.staff.name),
    },
    upcoming: upcoming[0] ?? null,
    history: bookings,
  };
});

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const current = await db.customer.findFirst({ where: { id, salonId: ctx.salonId } });
  if (!current) throw notFound("Client not found.");
  const body = await parsePatch(req, customerInput);
  if (body.phone && body.phone !== current.phone) {
    const clash = await db.customer.findUnique({ where: { salonId_phone: { salonId: ctx.salonId, phone: body.phone } } });
    if (clash) throw conflict("Another client already has this phone number.");
  }
  if (body.preferredStaffId) {
    const s = await db.staff.findFirst({ where: { id: body.preferredStaffId, salonId: ctx.salonId } });
    if (!s) throw conflict("Staff member not found.");
  }
  const { birthday, ...rest } = body;
  await db.customer.update({
    where: { id },
    data: { ...rest, ...(birthday !== undefined ? { birthday: birthday ? dateColumn(birthday) : null } : {}) },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "customer.updated", entityType: "Customer", entityId: id, metadata: { fields: Object.keys(body) } });
  const updated = await db.customer.findUniqueOrThrow({ where: { id } });
  return { ...updated, birthday: updated.birthday ? dateColumnToString(updated.birthday) : null };
});
