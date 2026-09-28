import { z } from "zod";
import { db } from "@/lib/db";
import { conflict, forbidden, ok, parseBody, parseQuery, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { DATE_RE, dayRange } from "@/lib/time";
import { audit } from "@/server/audit";

const querySchema = z.object({
  from: z.string().regex(DATE_RE),
  to: z.string().regex(DATE_RE),
  staffId: z.string().uuid().optional(),
});

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, querySchema);
  const start = dayRange(q.from, ctx.timezone).start;
  const end = dayRange(q.to, ctx.timezone).end;
  const staffFilter = ctx.role === "STAFF" ? ctx.staffId! : q.staffId;
  return db.blockedTime.findMany({
    where: {
      salonId: ctx.salonId,
      startTime: { lt: end },
      endTime: { gt: start },
      ...(staffFilter ? { OR: [{ staffId: staffFilter }, { staffId: null }] } : {}),
    },
    orderBy: { startTime: "asc" },
  });
});

const schema = z
  .object({
    staffId: z.string().uuid().nullable(), // null = whole salon
    startTime: z.coerce.date(),
    endTime: z.coerce.date(),
    type: z.enum(["LUNCH", "BREAK", "PERSONAL", "MEETING", "PRIVATE_BOOKING", "OTHER"]).default("OTHER"),
    note: z.string().trim().max(200).nullable().optional(),
    force: z.boolean().default(false),
  })
  .refine((v) => v.endTime > v.startTime, { message: "The block must end after it starts." });

/** Lunch, breaks, meetings, private bookings — blocked periods can't be booked. */
export const POST = route(async (req) => {
  const ctx = await requireSalon(req);
  const body = await parseBody(req, schema);
  if (ctx.role === "STAFF" && body.staffId !== ctx.staffId) throw forbidden("You can only block your own time.");
  if (ctx.role === "RECEPTIONIST" && body.staffId === null) throw forbidden("Only managers can close the whole salon.");
  if (body.staffId) {
    const s = await db.staff.findFirst({ where: { id: body.staffId, salonId: ctx.salonId }, select: { id: true } });
    if (!s) throw forbidden("Staff member not found.");
  }

  const clashes = await db.booking.findMany({
    where: {
      salonId: ctx.salonId,
      ...(body.staffId ? { staffId: body.staffId } : {}),
      status: { in: ["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE"] },
      startTime: { lt: body.endTime },
      blockedUntil: { gt: body.startTime },
    },
    select: { id: true, reference: true, startTime: true, customer: { select: { name: true } } },
  });
  if (clashes.length > 0 && !body.force) {
    throw conflict(`${clashes.length} booking(s) already fall in this time.`, { clashes });
  }

  const row = await db.blockedTime.create({
    data: {
      salonId: ctx.salonId,
      staffId: body.staffId,
      startTime: body.startTime,
      endTime: body.endTime,
      type: body.type,
      note: body.note ?? null,
      createdById: ctx.user.id,
    },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "blocked.created", entityType: "BlockedTime", entityId: row.id });
  return ok(row, "Time blocked.", 201);
});
