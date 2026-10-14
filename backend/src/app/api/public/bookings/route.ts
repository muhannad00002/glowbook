import { z } from "zod";
import { ApiError, badRequest, ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { signBookingToken, verifyPhoneToken } from "@/lib/auth/tokens";
import { createBookings, MAX_SERVICES_PER_VISIT } from "@/server/booking/engine";
import { afterResponse } from "@/server/booking/access";
import { findPublishedSalon } from "@/server/booking/query";
import { loadCustomerBooking } from "@/server/booking/customer-actions";
import { resolveCustomer } from "@/server/customers";
import { notifyBookingEvent } from "@/server/notifications/service";
import { activeGateway } from "@/server/payments/service";
import { audit } from "@/server/audit";

const schema = z
  .object({
    salon: z.string().min(1),
    /** Services booked back to back in this order (or the single `serviceId`). */
    serviceIds: z.array(z.string().uuid()).min(1).max(MAX_SERVICES_PER_VISIT).optional(),
    serviceId: z.string().uuid().optional(),
    staffId: z.string().uuid().nullable(), // null = any available
    startTime: z.coerce.date(),
    customer: z.object({
      name: z.string().trim().min(2, "Please enter your name.").max(80),
      phone: phoneSchema,
      email: z.string().trim().toLowerCase().email().optional().or(z.literal("").transform(() => undefined)),
    }),
    notes: z.string().trim().max(500).optional(),
    /** From POST /api/public/phone/verify — proves the customer owns `customer.phone`. */
    phoneToken: z.string().optional(),
    source: z.enum(["CUSTOMER_APP", "PUBLIC_PAGE"]).default("PUBLIC_PAGE"),
  })
  .refine((v) => v.serviceIds?.length || v.serviceId, { message: "Choose at least one service." });

/**
 * Customer booking — signed in (app) or as a guest (public booking page).
 *
 * The customer's phone must be verified: either a phone token from the one-time-code
 * step. This is enforced here, not just in the app. Customers have no accounts — even
 * if a team member is signed in on this device, the booking is the customer's — and they
 * get a signed manage link afterwards.
 */
export const POST = route(async (req) => {
  const body = await parseBody(req, schema);
  const salon = await findPublishedSalon(body.salon);
  if (!salon.isPublished) throw badRequest("This salon isn't taking online bookings.");

  const tokenPhone = body.phoneToken ? await verifyPhoneToken(body.phoneToken) : null;
  if (body.phoneToken && !tokenPhone) {
    throw new ApiError(401, "Your verification has expired. Please verify your phone again.", { needsVerification: true });
  }
  if (tokenPhone !== body.customer.phone) {
    throw new ApiError(403, "Please verify your phone number to book.", { needsVerification: true });
  }

  const customer = await resolveCustomer({
    salonId: salon.id,
    verifiedPhone: tokenPhone,
    name: body.customer.name,
    phone: body.customer.phone,
    email: body.customer.email,
    source: "PUBLIC_PAGE",
  });

  const bookings = await createBookings({
    salonId: salon.id,
    serviceIds: body.serviceIds?.length ? body.serviceIds : [body.serviceId!],
    staffId: body.staffId,
    startTime: body.startTime,
    customerId: customer.id,
    source: body.source,
    createdById: null,
    customerNotes: body.notes,
    enforceNotice: true,
  });
  const first = bookings[0];

  await audit({
    req,
    salonId: salon.id,
    action: "booking.created.online",
    entityType: "Booking",
    entityId: first.id,
    metadata: { references: bookings.map((b) => b.reference) },
  });
  afterResponse(async () => {
    for (const b of bookings) {
      await notifyBookingEvent(b.id, b.status === "CONFIRMED" ? "BOOKING_CONFIRMED" : "BOOKING_CREATED", { notifySalon: true });
    }
  });

  // One manage link covers the whole visit (the token names the group's first booking).
  const manageToken = await signBookingToken(first.id);
  const views = await Promise.all(bookings.map((b) => loadCustomerBooking(b.id, { token: manageToken })));
  const requiresPayment = bookings.some((b) => b.paymentRequirement !== "NONE" && b.paidBaisa < b.depositBaisa);
  return ok(
    {
      booking: views[0].booking,
      bookings: views.map((v) => v.booking),
      manageToken,
      requiresPayment,
      onlinePaymentAvailable: !!activeGateway(),
    },
    requiresPayment ? "Almost there — pay the deposit to secure your spot." : "Appointment confirmed 💕",
    201,
  );
});
