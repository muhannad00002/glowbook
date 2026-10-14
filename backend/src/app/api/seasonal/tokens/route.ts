import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { DATE_RE, dateColumn, localDate } from "@/lib/time";

const querySchema = z.object({
  date: z.string().regex(DATE_RE).optional(),
  eventId: z.string().uuid().optional(),
  offeringId: z.string().uuid().optional(),
  includeUnpaid: z.enum(["true", "false"]).default("false"),
});

/** The day's token queue, in token order. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const q = parseQuery(req, querySchema);
  const date = q.date ?? localDate(new Date(), ctx.timezone);
  const rows = await db.seasonalToken.findMany({
    where: {
      salonId: ctx.salonId,
      date: dateColumn(date),
      ...(q.offeringId ? { offeringId: q.offeringId } : {}),
      ...(q.eventId ? { offering: { eventId: q.eventId } } : {}),
      status: q.includeUnpaid === "true" ? undefined : { notIn: ["PENDING_PAYMENT", "EXPIRED"] },
    },
    select: {
      id: true,
      reference: true,
      number: true,
      startTime: true,
      endTime: true,
      status: true,
      priceBaisa: true,
      prepayBaisa: true,
      paidBaisa: true,
      paidAt: true,
      arrivedAt: true,
      completedAt: true,
      customerNotes: true,
      offering: { select: { id: true, name: true, nameAr: true, eventId: true } },
      customer: { select: { id: true, name: true, phone: true } },
    },
    orderBy: [{ startTime: "asc" }, { number: "asc" }],
  });
  const count = (s: string) => rows.filter((r) => r.status === s).length;
  return {
    date,
    tokens: rows.map((r) => ({ ...r, balanceBaisa: Math.max(0, r.priceBaisa - r.paidBaisa) })),
    summary: {
      total: rows.filter((r) => r.status !== "CANCELLED").length,
      waiting: count("CONFIRMED"),
      arrived: count("ARRIVED"),
      completed: count("COMPLETED"),
      noShow: count("NO_SHOW"),
      collectedBaisa: rows.filter((r) => r.status !== "CANCELLED").reduce((s, r) => s + r.paidBaisa, 0),
    },
  };
});
