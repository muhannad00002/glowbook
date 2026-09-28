import { z } from "zod";
import type { NextRequest } from "next/server";
import { parseQuery, route } from "@/lib/http";
import { DATE_RE } from "@/lib/time";
import { availabilityFor, isDeskCaller } from "@/server/booking/query";

const schema = z.object({
  salon: z.string().min(1),
  serviceId: z.string().uuid(),
  from: z.string().regex(DATE_RE, "Use YYYY-MM-DD."),
  days: z.coerce.number().int().min(1).max(42).default(14),
  staffId: z.string().uuid().optional(),
  desk: z.enum(["true", "false"]).optional(),
});

/** Per-day availability summary for the date strip / month picker. */
export const GET = route(async (req: NextRequest) => {
  const q = parseQuery(req, schema);
  const res = await availabilityFor({
    salonIdOrSlug: q.salon,
    serviceId: q.serviceId,
    staffId: q.staffId,
    fromDate: q.from,
    days: q.days,
    desk: (salonId) => isDeskCaller(req, salonId),
  });
  return {
    timezone: res.timezone,
    days: res.days.map((d) => ({
      date: d.date,
      closed: d.closed,
      slotCount: d.slots.length,
      firstSlot: d.slots[0]?.time ?? null,
    })),
  };
});
