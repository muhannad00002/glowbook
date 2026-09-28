import { z } from "zod";
import type { NextRequest } from "next/server";
import { parseQuery, route } from "@/lib/http";
import { DATE_RE } from "@/lib/time";
import { availabilityFor, isDeskCaller } from "@/server/booking/query";

const schema = z.object({
  salon: z.string().min(1, "Which salon?"),
  serviceId: z.string().uuid(),
  date: z.string().regex(DATE_RE, "Use YYYY-MM-DD."),
  staffId: z.string().uuid().optional(),
  desk: z.enum(["true", "false"]).optional(),
});

/**
 * Bookable start times for one day. Public: customers (and the public booking page)
 * call it without signing in. Omit `staffId` for "Any available".
 */
export const GET = route(async (req: NextRequest) => {
  const q = parseQuery(req, schema);
  const res = await availabilityFor({
    salonIdOrSlug: q.salon,
    serviceId: q.serviceId,
    staffId: q.staffId,
    fromDate: q.date,
    days: 1,
    desk: (salonId) => isDeskCaller(req, salonId),
  });
  const day = res.days[0] ?? { date: q.date, closed: true, slots: [] };
  return { ...res, days: undefined, date: day.date, closed: day.closed, slots: day.slots };
});
