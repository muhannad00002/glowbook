import type { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { badRequest, notFound } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { addDays, localDate, localMinute } from "@/lib/time";
import { buildDay, generateSlots, loadAvailabilityData } from "./availability";
import { loadVisit } from "./engine";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function findPublishedSalon(idOrSlug: string) {
  const salon = await db.salon.findFirst({
    where: UUID_RE.test(idOrSlug) ? { id: idOrSlug } : { slug: idOrSlug.toLowerCase() },
  });
  if (!salon) throw notFound("Salon not found.");
  return salon;
}

/** The front desk may book inside the min-notice window; customers may not. */
export async function isDeskCaller(req: NextRequest, salonId: string) {
  if (req.nextUrl.searchParams.get("desk") !== "true") return false;
  const user = await optionalUser(req);
  if (!user) return false;
  const m = await db.salonMember.findUnique({ where: { salonId_userId: { salonId, userId: user.id } } });
  return !!m?.isActive && m.role !== "STAFF";
}

export async function availabilityFor(input: {
  salonIdOrSlug: string;
  /** One or more services booked back to back with the same artist. */
  serviceIds: string[];
  staffId?: string | null;
  fromDate: string;
  days: number;
  desk: boolean | ((salonId: string) => Promise<boolean>);
}) {
  const salon = await findPublishedSalon(input.salonIdOrSlug);
  const desk = typeof input.desk === "function" ? await input.desk(salon.id) : input.desk;
  if (!salon.isPublished && !desk) throw notFound("Salon not found.");

  const visit = await loadVisit(db, salon.id, input.serviceIds);
  let staffIds = visit.eligible;
  if (input.staffId) {
    if (!staffIds.includes(input.staffId)) {
      throw badRequest(visit.services.length > 1 ? "This artist doesn't offer all of these services." : "This artist doesn't offer that service.");
    }
    staffIds = [input.staffId];
  }

  const now = new Date();
  const today = localDate(now, salon.timezone);
  const lastBookable = addDays(today, salon.bookingHorizonDays);
  const from = input.fromDate < today ? today : input.fromDate;
  const to = addDays(from, input.days - 1) > lastBookable && !desk ? lastBookable : addDays(from, input.days - 1);

  const days: { date: string; closed: boolean; slots: { start: string; end: string; time: string; staffIds: string[] }[] }[] = [];
  if (from <= to && staffIds.length > 0) {
    const data = await loadAvailabilityData(db, salon, staffIds, from, to);
    for (let d = from; d <= to; d = addDays(d, 1)) {
      const plan = buildDay(data, d);
      const slots = generateSlots(plan, salon, {
        durationMinutes: visit.durationMinutes,
        bufferMinutes: visit.bufferMinutes,
        now,
        enforceNotice: !desk,
      });
      days.push({
        date: d,
        closed: plan.closed,
        slots: slots.map((s) => {
          const start = new Date(s.start);
          const m = localMinute(start, salon.timezone);
          return {
            start: start.toISOString(),
            end: new Date(s.end).toISOString(),
            time: `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`,
            staffIds: s.staffIds,
          };
        }),
      });
    }
  }

  return {
    salonId: salon.id,
    timezone: salon.timezone,
    visit: {
      serviceIds: visit.services.map((s) => s.id),
      durationMinutes: visit.durationMinutes,
      priceBaisa: visit.services.reduce((sum, s) => sum + s.priceBaisa, 0),
    },
    staffIds,
    days,
  };
}
