import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseBody, route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { phoneSchema } from "@/lib/auth/password";
import { signBookingToken } from "@/lib/auth/tokens";
import { createBooking } from "@/server/booking/engine";
import { afterResponse } from "@/server/booking/access";
import { findPublishedSalon } from "@/server/booking/query";
import { loadCustomerBooking } from "@/server/booking/customer-actions";
import { resolveCustomer } from "@/server/customers";
import { notifyBookingEvent } from "@/server/notifications/service";
import { activeGateway } from "@/server/payments/service";
import { audit } from "@/server/audit";

const schema = z.object({
  salon: z.string().min(1),
  serviceId: z.string().uuid(),
  staffId: z.string().uuid().nullable(), // null = any available
  startTime: z.coerce.date(),
  customer: z.object({
    name: z.string().trim().min(2, "Please enter your name.").max(80),
    phone: phoneSchema,
    email: z.string().trim().toLowerCase().email().optional().or(z.literal("").transform(() => undefined)),
  }),
  notes: z.string().trim().max(500).optional(),
  source: z.enum(["CUSTOMER_APP", "PUBLIC_PAGE"]).default("PUBLIC_PAGE"),
});

/**
 * Customer booking — signed in (app) or as a guest (public booking page). Guests get a
 * signed manage link to view, pay or cancel without an account.
 */
export const POST = route(async (req) => {
  const body = await parseBody(req, schema);
  const user = await optionalUser(req);
  const salon = await findPublishedSalon(body.salon);
  if (!salon.isPublished) throw badRequest("This salon isn't taking online bookings.");

  let verifiedPhone: string | null = null;
  if (user) {
    const u = await db.user.findUnique({ where: { id: user.id }, select: { phone: true, phoneVerifiedAt: true } });
    verifiedPhone = u?.phoneVerifiedAt ? u.phone : null;
  }
  const customer = await resolveCustomer({
    salonId: salon.id,
    userId: user?.id,
    verifiedPhone,
    name: body.customer.name,
    phone: body.customer.phone,
    email: body.customer.email ?? user?.email,
    source: user ? "APP" : "PUBLIC_PAGE",
  });

  const booking = await createBooking({
    salonId: salon.id,
    serviceId: body.serviceId,
    staffId: body.staffId,
    startTime: body.startTime,
    customerId: customer.id,
    source: user ? "CUSTOMER_APP" : body.source,
    createdById: user?.id ?? null,
    customerNotes: body.notes,
    enforceNotice: true,
  });

  await audit({ req, salonId: salon.id, userId: user?.id, action: "booking.created.online", entityType: "Booking", entityId: booking.id, metadata: { reference: booking.reference } });
  afterResponse(() =>
    notifyBookingEvent(booking.id, booking.status === "CONFIRMED" ? "BOOKING_CONFIRMED" : "BOOKING_CREATED", { notifySalon: true }),
  );

  const manageToken = await signBookingToken(booking.id);
  const view = await loadCustomerBooking(booking.id, { user, token: manageToken });
  const requiresPayment = booking.paymentRequirement !== "NONE" && booking.paidBaisa < booking.depositBaisa;
  return ok(
    {
      booking: view.booking,
      manageToken,
      requiresPayment,
      onlinePaymentAvailable: !!activeGateway(),
    },
    requiresPayment ? "Almost there — pay the deposit to secure your spot." : "Appointment confirmed 💕",
    201,
  );
});
