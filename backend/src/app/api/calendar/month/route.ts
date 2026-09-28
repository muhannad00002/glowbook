import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { addDays, dateColumn, dateColumnToString, dayRange, localDate } from "@/lib/time";

const schema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/, "Use YYYY-MM."),
  staffId: z.string().uuid().optional(),
});

/** Month grid: per-day counts by status for the dots/heat of the month view. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, schema);
  const first = `${q.month}-01`;
  const [y, m] = q.month.split("-").map(Number);
  const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const last = addDays(first, daysInMonth - 1);
  const onlyStaff = ctx.role === "STAFF" ? ctx.staffId! : q.staffId;

  const [bookings, holidays] = await Promise.all([
    db.booking.findMany({
      where: {
        salonId: ctx.salonId,
        startTime: { gte: dayRange(first, ctx.timezone).start, lt: dayRange(last, ctx.timezone).end },
        ...(onlyStaff ? { staffId: onlyStaff } : {}),
      },
      select: { startTime: true, status: true, priceBaisa: true },
    }),
    db.salonHoliday.findMany({ where: { salonId: ctx.salonId, date: { gte: dateColumn(first), lte: dateColumn(last) } } }),
  ]);

  const days = new Map<string, { date: string; total: number; byStatus: Record<string, number>; bookedValueBaisa: number }>();
  for (let d = first; d <= last; d = addDays(d, 1)) days.set(d, { date: d, total: 0, byStatus: {}, bookedValueBaisa: 0 });
  for (const b of bookings) {
    const day = days.get(localDate(b.startTime, ctx.timezone));
    if (!day) continue;
    day.byStatus[b.status] = (day.byStatus[b.status] ?? 0) + 1;
    if (b.status !== "CANCELLED" && b.status !== "NO_SHOW") {
      day.total++;
      day.bookedValueBaisa += b.priceBaisa;
    }
  }

  return {
    month: q.month,
    timezone: ctx.timezone,
    days: [...days.values()],
    holidays: holidays.map((h) => ({ ...h, date: dateColumnToString(h.date) })),
  };
});
