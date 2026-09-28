import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { addDays, DATE_RE, dayOfWeek, dayRange, localDate } from "@/lib/time";

const schema = z.object({
  from: z.string().regex(DATE_RE).optional(),
  to: z.string().regex(DATE_RE).optional(), // inclusive
});

type DayRow = { d: string; amount: bigint | number | null };

/** Business analytics for a date range (defaults to the last 30 days). */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const q = parseQuery(req, schema);
  const today = localDate(new Date(), ctx.timezone);
  const to = q.to ?? today;
  const from = q.from ?? addDays(to, -29);
  if (from > to) throw badRequest("`from` must be before `to`.");
  if (addDays(from, 366) < to) throw badRequest("Pick a range of a year or less.");
  const start = dayRange(from, ctx.timezone).start;
  const end = dayRange(to, ctx.timezone).end;
  const tz = ctx.timezone;
  const salonId = ctx.salonId;

  const [revenueRows, bookings, reviews, customerRows] = await Promise.all([
    db.$queryRaw<DayRow[]>`
      SELECT to_char(("paidAt" AT TIME ZONE ${tz})::date, 'YYYY-MM-DD') AS d,
             SUM(CASE WHEN "kind" = 'REFUND' THEN -"amountBaisa" ELSE "amountBaisa" END) AS amount
      FROM "Payment"
      WHERE "salonId" = ${salonId} AND "status" = 'PAID' AND "paidAt" >= ${start} AND "paidAt" < ${end}
      GROUP BY 1 ORDER BY 1`,
    db.booking.findMany({
      where: { salonId, startTime: { gte: start, lt: end } },
      select: {
        status: true,
        priceBaisa: true,
        serviceId: true,
        staffId: true,
        service: { select: { name: true, nameAr: true } },
        staff: { select: { name: true, nameAr: true, color: true, photoUrl: true } },
      },
    }),
    db.review.findMany({ where: { salonId, createdAt: { gte: start, lt: end } }, select: { staffId: true, rating: true } }),
    // First-ever (non-cancelled) visit per customer who visited in range → new vs returning.
    db.$queryRaw<{ customerId: string; first: Date }[]>`
      SELECT b."customerId", MIN(b."startTime") AS first
      FROM "Booking" b
      WHERE b."salonId" = ${salonId} AND b."status" NOT IN ('CANCELLED', 'NO_SHOW')
        AND b."customerId" IN (
          SELECT "customerId" FROM "Booking"
          WHERE "salonId" = ${salonId} AND "startTime" >= ${start} AND "startTime" < ${end}
            AND "status" NOT IN ('CANCELLED', 'NO_SHOW'))
      GROUP BY b."customerId"`,
  ]);

  // Revenue: daily series (zero-filled), then weekly (weeks start Saturday) and monthly rollups.
  const byDay = new Map(revenueRows.map((r) => [r.d, Number(r.amount ?? 0)]));
  const daily: { date: string; revenueBaisa: number }[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) daily.push({ date: d, revenueBaisa: byDay.get(d) ?? 0 });
  const weekly = new Map<string, number>();
  const monthly = new Map<string, number>();
  for (const { date, revenueBaisa } of daily) {
    const weekStart = addDays(date, -((dayOfWeek(date) + 1) % 7)); // back to Saturday
    weekly.set(weekStart, (weekly.get(weekStart) ?? 0) + revenueBaisa);
    monthly.set(date.slice(0, 7), (monthly.get(date.slice(0, 7)) ?? 0) + revenueBaisa);
  }
  const totalRevenue = daily.reduce((s, d) => s + d.revenueBaisa, 0);

  // Bookings.
  const byStatus: Record<string, number> = {};
  for (const b of bookings) byStatus[b.status] = (byStatus[b.status] ?? 0) + 1;
  const total = bookings.length;
  const cancelled = byStatus.CANCELLED ?? 0;
  const noShows = byStatus.NO_SHOW ?? 0;

  // Popular services (all non-cancelled bookings).
  const svc = new Map<string, { serviceId: string; name: string; nameAr: string | null; count: number; revenueBaisa: number }>();
  for (const b of bookings) {
    if (b.status === "CANCELLED") continue;
    const s = svc.get(b.serviceId) ?? { serviceId: b.serviceId, name: b.service.name, nameAr: b.service.nameAr, count: 0, revenueBaisa: 0 };
    s.count++;
    if (b.status === "COMPLETED") s.revenueBaisa += b.priceBaisa;
    svc.set(b.serviceId, s);
  }

  // Staff performance.
  const staff = new Map<
    string,
    { staffId: string; name: string; nameAr: string | null; color: string; photoUrl: string | null; bookings: number; completed: number; noShows: number; revenueBaisa: number; ratingSum: number; ratingCount: number }
  >();
  for (const b of bookings) {
    const s = staff.get(b.staffId) ?? {
      staffId: b.staffId,
      name: b.staff.name,
      nameAr: b.staff.nameAr,
      color: b.staff.color,
      photoUrl: b.staff.photoUrl,
      bookings: 0,
      completed: 0,
      noShows: 0,
      revenueBaisa: 0,
      ratingSum: 0,
      ratingCount: 0,
    };
    if (b.status !== "CANCELLED") s.bookings++;
    if (b.status === "COMPLETED") {
      s.completed++;
      s.revenueBaisa += b.priceBaisa;
    }
    if (b.status === "NO_SHOW") s.noShows++;
    staff.set(b.staffId, s);
  }
  for (const r of reviews) {
    const s = r.staffId ? staff.get(r.staffId) : undefined;
    if (s) {
      s.ratingSum += r.rating;
      s.ratingCount++;
    }
  }

  const newCustomers = customerRows.filter((c) => c.first >= start && c.first < end).length;

  return {
    from,
    to,
    timezone: tz,
    revenue: {
      totalBaisa: totalRevenue,
      averagePerDayBaisa: Math.round(totalRevenue / daily.length),
      daily,
      weekly: [...weekly.entries()].map(([weekStart, revenueBaisa]) => ({ weekStart, revenueBaisa })),
      monthly: [...monthly.entries()].map(([month, revenueBaisa]) => ({ month, revenueBaisa })),
    },
    bookings: {
      total,
      byStatus,
      completed: byStatus.COMPLETED ?? 0,
      cancelled,
      noShows,
      cancellationRate: total ? cancelled / total : 0,
      noShowRate: total ? noShows / total : 0,
    },
    popularServices: [...svc.values()].sort((a, b) => b.count - a.count),
    staffPerformance: [...staff.values()]
      .map(({ ratingSum, ratingCount, ...s }) => ({ ...s, avgRating: ratingCount ? Math.round((ratingSum / ratingCount) * 10) / 10 : null, reviewCount: ratingCount }))
      .sort((a, b) => b.revenueBaisa - a.revenueBaisa),
    customers: {
      total: customerRows.length,
      new: newCustomers,
      returning: customerRows.length - newCustomers,
      retentionRate: customerRows.length ? (customerRows.length - newCustomers) / customerRows.length : 0,
    },
  };
});
