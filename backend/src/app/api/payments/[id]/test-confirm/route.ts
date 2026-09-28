import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, notFound, ok, parseBody, route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { afterResponse } from "@/server/booking/access";
import { loadCustomerBooking } from "@/server/booking/customer-actions";
import { markOnlinePaymentPaid } from "@/server/payments/service";
import { notifyBookingEvent } from "@/server/notifications/service";

const schema = z.object({ token: z.string().optional(), succeed: z.boolean().default(true) });

/**
 * Sandbox checkout completion. Exists ONLY when PAYMENT_PROVIDER=test — it plays the
 * role a real gateway's webhook plays in production. No money moves.
 */
export const POST = route(async (req, { id }) => {
  if (process.env.PAYMENT_PROVIDER !== "test") throw notFound();
  const body = await parseBody(req, schema);
  const payment = await db.payment.findUnique({ where: { id } });
  if (!payment || payment.provider !== "test") throw notFound("Payment not found.");
  await loadCustomerBooking(payment.bookingId, { user: await optionalUser(req), token: body.token });

  if (!body.succeed) {
    await db.payment.updateMany({ where: { id, status: "PENDING" }, data: { status: "FAILED" } });
    throw badRequest("The test payment was declined.");
  }
  const { confirmed } = await markOnlinePaymentPaid(id);
  if (confirmed) afterResponse(() => notifyBookingEvent(payment.bookingId, "BOOKING_CONFIRMED", { notifySalon: true }));
  const view = await loadCustomerBooking(payment.bookingId, { user: await optionalUser(req), token: body.token });
  return ok({ booking: view.booking, confirmed }, "Payment received 💕");
});
