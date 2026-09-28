import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { DATE_RE, dateColumn, dateColumnToString, localDate } from "@/lib/time";

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const today = localDate(new Date(), ctx.timezone);
  const rows = await db.salonHoliday.findMany({
    where: { salonId: ctx.salonId, date: { gte: dateColumn(today) } },
    orderBy: { date: "asc" },
  });
  return rows.map((h) => ({ ...h, date: dateColumnToString(h.date) }));
});

const schema = z
  .object({
    date: z.string().regex(DATE_RE, "Use YYYY-MM-DD."),
    name: z.string().trim().min(1).max(80),
    isClosed: z.boolean().default(true),
    openMinute: z.number().int().min(0).max(1439).nullable().optional(),
    closeMinute: z.number().int().min(1).max(1440).nullable().optional(),
  })
  .refine((v) => v.isClosed || (v.openMinute != null && v.closeMinute != null && v.closeMinute > v.openMinute), {
    message: "Special hours need an opening and a later closing time.",
  });

/** A closed day, or a day with special hours. Upserts by date. */
export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, schema);
  if (body.date < localDate(new Date(), ctx.timezone)) throw badRequest("That date is in the past.");
  const data = {
    name: body.name,
    isClosed: body.isClosed,
    openMinute: body.isClosed ? null : body.openMinute,
    closeMinute: body.isClosed ? null : body.closeMinute,
  };
  const row = await db.salonHoliday.upsert({
    where: { salonId_date: { salonId: ctx.salonId, date: dateColumn(body.date) } },
    create: { salonId: ctx.salonId, date: dateColumn(body.date), ...data },
    update: data,
  });
  return ok({ ...row, date: body.date }, null, 201);
});
