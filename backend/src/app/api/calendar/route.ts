import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, parseQuery, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { addDays, DATE_RE, dateColumn, dateColumnToString, dayRange } from "@/lib/time";
import { bookingSalonSelect } from "@/server/dto";

const schema = z.object({
  from: z.string().regex(DATE_RE),
  to: z.string().regex(DATE_RE), // inclusive
  staffId: z.string().uuid().optional(),
});

/**
 * Everything the Day / Week calendar needs in one round trip: staff columns with their
 * shifts, salon hours, closures, bookings, blocked time and leave in the range.
 */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, schema);
  if (q.to < q.from) throw badRequest("`to` must be on or after `from`.");
  if (addDays(q.from, 31) < q.to) throw badRequest("Use the month view for ranges over a month.");

  const start = dayRange(q.from, ctx.timezone).start;
  const end = dayRange(q.to, ctx.timezone).end;
  const onlyStaff = ctx.role === "STAFF" ? ctx.staffId! : q.staffId;
  const overlaps = { startTime: { lt: end }, endTime: { gt: start } };

  const [staff, salonHours, holidays, bookings, blocked, timeOff] = await Promise.all([
    db.staff.findMany({
      where: { salonId: ctx.salonId, isActive: true, ...(onlyStaff ? { id: onlyStaff } : {}) },
      select: {
        id: true,
        name: true,
        nameAr: true,
        title: true,
        titleAr: true,
        color: true,
        photoUrl: true,
        hours: { select: { dayOfWeek: true, startMinute: true, endMinute: true } },
      },
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    }),
    db.salonWorkingHour.findMany({ where: { salonId: ctx.salonId }, orderBy: { dayOfWeek: "asc" } }),
    db.salonHoliday.findMany({ where: { salonId: ctx.salonId, date: { gte: dateColumn(q.from), lte: dateColumn(q.to) } } }),
    db.booking.findMany({
      where: { salonId: ctx.salonId, ...overlaps, ...(onlyStaff ? { staffId: onlyStaff } : {}) },
      select: bookingSalonSelect,
      orderBy: { startTime: "asc" },
    }),
    db.blockedTime.findMany({
      where: { salonId: ctx.salonId, ...overlaps, ...(onlyStaff ? { OR: [{ staffId: onlyStaff }, { staffId: null }] } : {}) },
      orderBy: { startTime: "asc" },
    }),
    db.staffTimeOff.findMany({
      where: { salonId: ctx.salonId, ...overlaps, ...(onlyStaff ? { staffId: onlyStaff } : {}) },
    }),
  ]);

  return {
    from: q.from,
    to: q.to,
    timezone: ctx.timezone,
    staff,
    salonHours,
    holidays: holidays.map((h) => ({ ...h, date: dateColumnToString(h.date) })),
    bookings,
    blocked,
    timeOff,
  };
});
