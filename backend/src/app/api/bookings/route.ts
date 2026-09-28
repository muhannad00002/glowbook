import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseBody, parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { phoneSchema } from "@/lib/auth/password";
import { DATE_RE, dayRange } from "@/lib/time";
import { bookingSalonSelect } from "@/server/dto";
import { createBooking } from "@/server/booking/engine";
import { afterResponse } from "@/server/booking/access";
import { resolveCustomer } from "@/server/customers";
import { notifyBookingEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";
import type { Prisma } from "@/generated/prisma/client";

const STATUSES = ["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE", "COMPLETED", "CANCELLED", "NO_SHOW"] as const;

const querySchema = z.object({
  from: z.string().regex(DATE_RE).optional(),
  to: z.string().regex(DATE_RE).optional(), // inclusive
  staffId: z.string().uuid().optional(),
  customerId: z.string().uuid().optional(),
  status: z.string().optional(), // comma-separated
  q: z.string().trim().max(80).optional(),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, querySchema);
  const where: Prisma.BookingWhereInput = { salonId: ctx.salonId };
  if (q.from) where.startTime = { gte: dayRange(q.from, ctx.timezone).start };
  if (q.to) where.startTime = { ...(where.startTime as object), lt: dayRange(q.to, ctx.timezone).end };
  if (q.staffId) where.staffId = q.staffId;
  if (ctx.role === "STAFF") where.staffId = ctx.staffId!;
  if (q.customerId) where.customerId = q.customerId;
  if (q.status) {
    const list = q.status.split(",").filter((s): s is (typeof STATUSES)[number] => (STATUSES as readonly string[]).includes(s));
    if (list.length) where.status = { in: list };
  }
  if (q.q) {
    where.OR = [
      { reference: { contains: q.q.toUpperCase() } },
      { customer: { name: { contains: q.q, mode: "insensitive" } } },
      { customer: { phone: { contains: q.q.replace(/\D/g, "") || q.q } } },
    ];
  }
  return db.booking.findMany({ where, select: bookingSalonSelect, orderBy: { startTime: "asc" }, take: q.limit });
});

const createSchema = z
  .object({
    serviceId: z.string().uuid(),
    staffId: z.string().uuid().nullable(),
    startTime: z.coerce.date(),
    customerId: z.string().uuid().optional(),
    newCustomer: z
      .object({
        name: z.string().trim().min(2).max(80),
        phone: phoneSchema.optional(),
        email: z.string().trim().toLowerCase().email().optional(),
      })
      .optional(),
    customerNotes: z.string().trim().max(1000).nullable().optional(),
    internalNotes: z.string().trim().max(2000).nullable().optional(),
    source: z.enum(["WALK_IN", "ADMIN"]).default("ADMIN"),
    status: z.enum(["PENDING", "CONFIRMED", "ARRIVED"]).default("CONFIRMED"),
    notifyCustomer: z.boolean().default(true),
  })
  .refine((v) => v.customerId || v.newCustomer, { message: "Choose a client or add a new one." });

/** Front-desk booking (walk-ins, phone bookings). Same engine, same conflict rules. */
export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const body = await parseBody(req, createSchema);

  let customerId = body.customerId;
  if (customerId) {
    const c = await db.customer.findFirst({ where: { id: customerId, salonId: ctx.salonId }, select: { id: true } });
    if (!c) throw badRequest("Client not found.");
  } else {
    const c = await resolveCustomer({
      salonId: ctx.salonId,
      name: body.newCustomer!.name,
      phone: body.newCustomer!.phone,
      email: body.newCustomer!.email,
      source: body.source === "WALK_IN" ? "WALK_IN" : "ADMIN",
    });
    customerId = c.id;
  }

  const booking = await createBooking({
    salonId: ctx.salonId,
    serviceId: body.serviceId,
    staffId: body.staffId,
    startTime: body.startTime,
    customerId,
    source: body.source,
    createdById: ctx.user.id,
    customerNotes: body.customerNotes,
    internalNotes: body.internalNotes,
    enforceNotice: false,
    initialStatus: body.status,
  });

  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.created", entityType: "Booking", entityId: booking.id, metadata: { reference: booking.reference, source: body.source } });
  if (body.notifyCustomer) {
    afterResponse(() =>
      notifyBookingEvent(booking.id, booking.status === "PENDING" ? "BOOKING_CREATED" : "BOOKING_CONFIRMED", {
        notifySalon: true,
        actorUserId: ctx.user.id,
      }),
    );
  }
  const full = await db.booking.findUniqueOrThrow({ where: { id: booking.id }, select: bookingSalonSelect });
  return ok(full, "Appointment booked ✨", 201);
});
