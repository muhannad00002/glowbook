import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { dateColumn, dateColumnToString, localDate } from "@/lib/time";
import { findPublishedSalon } from "@/server/booking/query";
import { eventDates } from "@/server/seasonal/engine";
import { publicOffering } from "@/server/seasonal/access";

/** A salon's running and upcoming seasonal events: GET /api/public/seasonal?salon=slug */
export const GET = route(async (req) => {
  const q = parseQuery(req, z.object({ salon: z.string().min(1) }));
  const salon = await findPublishedSalon(q.salon);
  if (!salon.isPublished) return [];
  const today = localDate(new Date(), salon.timezone);
  const events = await db.seasonalEvent.findMany({
    where: { salonId: salon.id, isActive: true, endDate: { gte: dateColumn(today) } },
    include: { offerings: { where: { isActive: true }, orderBy: [{ sortOrder: "asc" }, { name: "asc" }] } },
    orderBy: { startDate: "asc" },
  });
  return events
    .filter((e) => e.offerings.length > 0)
    .map((e) => ({
      id: e.id,
      name: e.name,
      nameAr: e.nameAr,
      description: e.description,
      descriptionAr: e.descriptionAr,
      startDate: dateColumnToString(e.startDate),
      endDate: dateColumnToString(e.endDate),
      openMinute: e.openMinute,
      closeMinute: e.closeMinute,
      dates: eventDates(e, today),
      timezone: salon.timezone,
      offerings: e.offerings.map(publicOffering),
    }));
});
