import type { Tx } from "@/lib/db";
import { addDays, dateColumn, dateColumnToString, dayOfWeek, dayRange, localDate, zonedToUtc } from "@/lib/time";

/**
 * Availability = (salon hours ∩ staff hours on that weekday, or the holiday's special hours)
 *                minus (live bookings incl. buffer, staff time off, blocked time).
 *
 * Loading and computing are split: `loadAvailabilityData` pulls everything for a date
 * range in a handful of queries; `buildDay` / `generateSlots` / `checkSlot` are pure,
 * so the exact same rules decide both "which slots do we show" and "may this booking be
 * written" (the latter re-run inside the booking transaction under a lock).
 */

export type Interval = { start: number; end: number }; // epoch ms, half-open
export type SalonRules = {
  id: string;
  timezone: string;
  slotIntervalMinutes: number;
  minNoticeMinutes: number;
  bookingHorizonDays: number;
};
export type StaffDay = { staffId: string; work: Interval[]; busy: Interval[] };
export type DayPlan = { date: string; closed: boolean; staff: StaffDay[] };

const LIVE_EXCLUDED = ["CANCELLED", "NO_SHOW"] as const;

export type AvailabilityData = Awaited<ReturnType<typeof loadAvailabilityData>>;

export async function loadAvailabilityData(
  tx: Tx,
  salon: SalonRules,
  staffIds: string[],
  fromDate: string,
  toDate: string, // inclusive
  opts: { excludeBookingId?: string } = {},
) {
  const rangeStart = dayRange(fromDate, salon.timezone).start;
  const rangeEnd = dayRange(toDate, salon.timezone).end;
  const overlaps = { startTime: { lt: rangeEnd }, endTime: { gt: rangeStart } };

  const [salonHours, holidays, staffHours, bookings, timeOff, blocked] = await Promise.all([
    tx.salonWorkingHour.findMany({ where: { salonId: salon.id } }),
    tx.salonHoliday.findMany({
      where: { salonId: salon.id, date: { gte: dateColumn(fromDate), lte: dateColumn(toDate) } },
    }),
    tx.staffWorkingHour.findMany({ where: { staffId: { in: staffIds } } }),
    tx.booking.findMany({
      where: {
        staffId: { in: staffIds },
        status: { notIn: [...LIVE_EXCLUDED] },
        startTime: { lt: rangeEnd },
        blockedUntil: { gt: rangeStart },
        ...(opts.excludeBookingId ? { id: { not: opts.excludeBookingId } } : {}),
      },
      select: { staffId: true, startTime: true, blockedUntil: true },
    }),
    tx.staffTimeOff.findMany({ where: { staffId: { in: staffIds }, ...overlaps } }),
    tx.blockedTime.findMany({
      where: { salonId: salon.id, OR: [{ staffId: null }, { staffId: { in: staffIds } }], ...overlaps },
    }),
  ]);

  return { salon, staffIds, salonHours, holidays, staffHours, bookings, timeOff, blocked };
}

function intersect(a: [number, number], b: [number, number]): [number, number] | null {
  const s = Math.max(a[0], b[0]);
  const e = Math.min(a[1], b[1]);
  return e > s ? [s, e] : null;
}

/** Pure: the working and busy intervals of every staff member on one salon-local date. */
export function buildDay(data: AvailabilityData, date: string): DayPlan {
  const tz = data.salon.timezone;
  const dow = dayOfWeek(date);
  const holiday = data.holidays.find((h) => dateColumnToString(h.date) === date);

  let window: [number, number] | null = null;
  if (holiday) {
    if (!holiday.isClosed && holiday.openMinute != null && holiday.closeMinute != null) {
      window = [holiday.openMinute, holiday.closeMinute];
    }
  } else {
    const h = data.salonHours.find((x) => x.dayOfWeek === dow);
    if (h) window = [h.openMinute, h.closeMinute];
  }

  const { start: dayStart, end: dayEnd } = dayRange(date, tz);
  const staff: StaffDay[] = data.staffIds.map((staffId) => {
    const work: Interval[] = [];
    if (window) {
      for (const sh of data.staffHours.filter((x) => x.staffId === staffId && x.dayOfWeek === dow)) {
        const w = intersect([sh.startMinute, sh.endMinute], window);
        if (w) work.push({ start: zonedToUtc(date, w[0], tz).getTime(), end: zonedToUtc(date, w[1], tz).getTime() });
      }
    }
    const busy: Interval[] = [];
    const push = (s: Date, e: Date) => {
      if (s.getTime() < dayEnd.getTime() + 86400_000 && e.getTime() > dayStart.getTime() - 86400_000) {
        busy.push({ start: s.getTime(), end: e.getTime() });
      }
    };
    for (const b of data.bookings) if (b.staffId === staffId) push(b.startTime, b.blockedUntil);
    for (const t of data.timeOff) if (t.staffId === staffId) push(t.startTime, t.endTime);
    for (const bl of data.blocked) if (bl.staffId === null || bl.staffId === staffId) push(bl.startTime, bl.endTime);
    work.sort((a, b) => a.start - b.start);
    return { staffId, work, busy };
  });

  return { date, closed: window === null, staff };
}

const isFree = (busy: Interval[], s: number, e: number) => busy.every((b) => b.end <= s || b.start >= e);

export type SlotOptions = {
  durationMinutes: number;
  bufferMinutes: number;
  now: Date;
  /** Customer-facing requests respect minimum notice; the front desk may book "now". */
  enforceNotice: boolean;
};

export type Slot = { start: number; end: number; staffIds: string[] };

/** Pure: bookable start times on a day, each with the staff who could take it. */
export function generateSlots(plan: DayPlan, rules: SalonRules, opts: SlotOptions): Slot[] {
  const step = rules.slotIntervalMinutes * 60_000;
  const dur = opts.durationMinutes * 60_000;
  const buf = opts.bufferMinutes * 60_000;
  const earliest = opts.now.getTime() + (opts.enforceNotice ? rules.minNoticeMinutes * 60_000 : 0);
  const midnight = zonedToUtc(plan.date, 0, rules.timezone).getTime();

  const byStart = new Map<number, string[]>();
  for (const s of plan.staff) {
    for (const w of s.work) {
      let t = midnight + Math.ceil((w.start - midnight) / step) * step;
      for (; t + dur <= w.end; t += step) {
        if (t < earliest) continue;
        if (!isFree(s.busy, t, t + dur + buf)) continue;
        const list = byStart.get(t) ?? [];
        list.push(s.staffId);
        byStart.set(t, list);
      }
    }
  }
  return [...byStart.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([start, staffIds]) => ({ start, end: start + dur, staffIds }));
}

export type SlotProblem = "PAST" | "TOO_SOON" | "TOO_FAR" | "SALON_CLOSED" | "OUTSIDE_HOURS" | "UNAVAILABLE";

export const SLOT_PROBLEM_MESSAGES: Record<SlotProblem, string> = {
  PAST: "That time has already passed.",
  TOO_SOON: "That time is too soon to book online. Please choose a later slot.",
  TOO_FAR: "That date is too far ahead to book yet.",
  SALON_CLOSED: "The salon is closed on that day.",
  OUTSIDE_HOURS: "That time is outside working hours.",
  UNAVAILABLE: "Appointment is no longer available.",
};

/** Pure: may `staffId` take [start, start+duration(+buffer)) on this day? */
export function checkSlot(
  plan: DayPlan,
  rules: SalonRules,
  staffId: string,
  start: Date,
  opts: SlotOptions,
): SlotProblem | null {
  const s = start.getTime();
  const e = s + opts.durationMinutes * 60_000;
  const now = opts.now.getTime();
  if (s < now - 5 * 60_000) return "PAST";
  if (opts.enforceNotice) {
    if (s < now + rules.minNoticeMinutes * 60_000) return "TOO_SOON";
    const horizonEnd = dayRange(addDays(localDate(opts.now, rules.timezone), rules.bookingHorizonDays), rules.timezone).end;
    if (s >= horizonEnd.getTime()) return "TOO_FAR";
  }
  if (plan.closed) return "SALON_CLOSED";
  const day = plan.staff.find((x) => x.staffId === staffId);
  if (!day || !day.work.some((w) => w.start <= s && e <= w.end)) return "OUTSIDE_HOURS";
  if (!isFree(day.busy, s, e + opts.bufferMinutes * 60_000)) return "UNAVAILABLE";
  return null;
}
