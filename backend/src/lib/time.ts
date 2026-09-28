/**
 * Timezone helpers with zero dependencies.
 *
 * Schedules (working hours, holidays) are wall-clock values in the salon's timezone;
 * bookings are absolute instants. These helpers convert between the two. Never use
 * `toISOString().slice(0, 10)` for a "local date" — the server may run in UTC while
 * the salon lives in UTC+4.
 */

const dtfCache = new Map<string, Intl.DateTimeFormat>();

function formatter(timeZone: string) {
  let f = dtfCache.get(timeZone);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      weekday: "short",
    });
    dtfCache.set(timeZone, f);
  }
  return f;
}

type Parts = { year: number; month: number; day: number; hour: number; minute: number; second: number };

function partsOf(date: Date, timeZone: string): Parts {
  const out: Record<string, string> = {};
  for (const p of formatter(timeZone).formatToParts(date)) out[p.type] = p.value;
  return {
    year: +out.year,
    month: +out.month,
    day: +out.day,
    hour: +out.hour === 24 ? 0 : +out.hour,
    minute: +out.minute,
    second: +out.second,
  };
}

/** Offset of `timeZone` from UTC at `date`, in minutes (Asia/Muscat → +240). */
export function tzOffsetMinutes(date: Date, timeZone: string): number {
  const p = partsOf(date, timeZone);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return Math.round((asUtc - Math.floor(date.getTime() / 1000) * 1000) / 60000);
}

export const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Salon-local "YYYY-MM-DD" + minutes-from-midnight → the absolute instant. */
export function zonedToUtc(localDate: string, minuteOfDay: number, timeZone: string): Date {
  const [y, m, d] = localDate.split("-").map(Number);
  const naive = Date.UTC(y, m - 1, d, 0, minuteOfDay);
  const off1 = tzOffsetMinutes(new Date(naive), timeZone);
  let result = naive - off1 * 60000;
  const off2 = tzOffsetMinutes(new Date(result), timeZone);
  if (off2 !== off1) result = naive - off2 * 60000; // DST edge
  return new Date(result);
}

/** The salon-local calendar date of an instant, as "YYYY-MM-DD". */
export function localDate(date: Date, timeZone: string): string {
  const p = partsOf(date, timeZone);
  return `${p.year}-${String(p.month).padStart(2, "0")}-${String(p.day).padStart(2, "0")}`;
}

/** Minutes since salon-local midnight for an instant. */
export function localMinute(date: Date, timeZone: string): number {
  const p = partsOf(date, timeZone);
  return p.hour * 60 + p.minute;
}

/** 0 = Sunday … 6 = Saturday, for a "YYYY-MM-DD" calendar date. */
export function dayOfWeek(localDateStr: string): number {
  const [y, m, d] = localDateStr.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

export function addDays(localDateStr: string, days: number): string {
  const [y, m, d] = localDateStr.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + days));
  return t.toISOString().slice(0, 10); // safe: t is UTC midnight by construction
}

/** [start, end) instants covering one salon-local calendar day. */
export function dayRange(localDateStr: string, timeZone: string): { start: Date; end: Date } {
  return {
    start: zonedToUtc(localDateStr, 0, timeZone),
    end: zonedToUtc(addDays(localDateStr, 1), 0, timeZone),
  };
}

/** A @db.Date column value for a salon-local calendar date. */
export function dateColumn(localDateStr: string): Date {
  return new Date(`${localDateStr}T00:00:00.000Z`);
}

export function dateColumnToString(d: Date): string {
  return d.toISOString().slice(0, 10); // @db.Date values are UTC midnight
}

export function formatLocal(date: Date, timeZone: string, locale: string, opts: Intl.DateTimeFormatOptions) {
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-OM" : "en-GB", { timeZone, ...opts }).format(date);
}
