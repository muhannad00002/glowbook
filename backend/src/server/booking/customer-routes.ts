import type { NextRequest } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseBody } from "@/lib/http";
import type { AuthUser } from "@/lib/auth/context";
import { cancelBooking, rescheduleBooking } from "./engine";
import { afterResponse } from "./access";
import { assertCustomerCanReschedule, loadCustomerBooking } from "./customer-actions";
import { notifyBookingEvent } from "@/server/notifications/service";
import { markOnlinePaymentPaid, startOnlinePayment } from "@/server/payments/service";
import { audit } from "@/server/audit";

/**
 * Handlers shared by the signed-in routes (/api/my/bookings/:id/…) and the guest
 * routes (/api/public/bookings/:id/…). Only how the caller proves ownership differs.
 */
type Who = { user: AuthUser | null; token: string | null };

export async function handleCustomerCancel(req: NextRequest, id: string, who: Who) {
  const body = await parseBody(req, z.object({ reason: z.string().trim().max(300).optional(), token: z.string().optional() }));
  const { booking, salonId } = await loadCustomerBooking(id, { ...who, token: who.token ?? body.token });
  if (!booking.canCancel) throw badRequest("This booking can no longer be cancelled online. Please contact the salon.");
  const res = await cancelBooking({ salonId, bookingId: id, cancelledById: who.user?.id ?? null, bySalon: false, reason: body.reason });
  // Cancelling one part of a multi-service visit cancels the visit.
  const siblings = booking.groupId
    ? await db.booking.findMany({
        where: { groupId: booking.groupId, id: { not: id }, status: { in: ["PENDING", "CONFIRMED"] } },
        select: { id: true },
      })
    : [];
  for (const s of siblings) {
    await cancelBooking({ salonId, bookingId: s.id, cancelledById: who.user?.id ?? null, bySalon: false, reason: body.reason });
  }
  await audit({ req, salonId, userId: who.user?.id, action: "booking.cancelled.customer", entityType: "Booking", entityId: id, metadata: { alsoCancelled: siblings.map((s) => s.id) } });
  afterResponse(async () => {
    for (const bid of [id, ...siblings.map((s) => s.id)]) await notifyBookingEvent(bid, "BOOKING_CANCELLED", { notifySalon: true });
  });
  const view = await loadCustomerBooking(id, { ...who, token: who.token ?? body.token });
  return ok({ booking: view.booking, quote: res.quote }, "Your appointment has been cancelled.");
}

export async function handleCustomerReschedule(req: NextRequest, id: string, who: Who) {
  const body = await parseBody(
    req,
    z.object({ startTime: z.coerce.date(), staffId: z.string().uuid().nullable().optional(), token: z.string().optional() }),
  );
  const token = who.token ?? body.token ?? null;
  const { booking, salonId } = await loadCustomerBooking(id, { ...who, token });
  assertCustomerCanReschedule(booking);
  // Customers may only move within the free-cancellation window.
  if (!booking.cancellationQuote.isFreeCancellation) {
    throw badRequest("It's too close to your appointment to reschedule online. Please contact the salon.");
  }
  const { historyId, anchorId } = await rescheduleBooking({
    salonId,
    bookingId: id,
    startTime: body.startTime,
    staffId: body.staffId ?? undefined,
    changedById: who.user?.id ?? null,
    enforceNotice: true,
  });
  await audit({ req, salonId, userId: who.user?.id, action: "booking.rescheduled.customer", entityType: "Booking", entityId: id });
  afterResponse(() => notifyBookingEvent(anchorId, "BOOKING_RESCHEDULED", { eventKey: historyId, notifySalon: true }));
  const view = await loadCustomerBooking(id, { ...who, token });
  return ok(view.booking, "Your appointment has been moved ✨");
}

export async function handleCustomerPay(req: NextRequest, id: string, who: Who) {
  const body = await parseBody(
    req,
    z.object({ kind: z.enum(["DEPOSIT", "FULL", "BALANCE"]).default("DEPOSIT"), token: z.string().optional() }),
  );
  await loadCustomerBooking(id, { ...who, token: who.token ?? body.token });
  const payment = await startOnlinePayment({ bookingId: id, kind: body.kind });
  return ok(
    { paymentId: payment.id, amountBaisa: payment.amountBaisa, checkoutUrl: payment.checkoutUrl, provider: payment.provider },
    null,
    201,
  );
}

export { markOnlinePaymentPaid };
