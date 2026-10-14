import { db } from "@/lib/db";
import { badRequest, forbidden, notFound } from "@/lib/http";
import type { AuthUser } from "@/lib/auth/context";
import { verifyBookingToken } from "@/lib/auth/tokens";
import { bookingCustomerSelect } from "@/server/dto";
import { quoteCancellation } from "./engine";

/**
 * Customer-side access to a booking: either the signed-in owner, or a guest holding the
 * signed manage-link token issued when she booked from the public page.
 */
export async function loadCustomerBooking(id: string, who: { user?: AuthUser | null; token?: string | null }) {
  const row = await db.booking.findUnique({
    where: { id },
    select: { ...bookingCustomerSelect, customer: { select: { userId: true, name: true, phone: true, email: true } } },
  });
  if (!row) throw notFound("Booking not found.");

  const ownerOk = !!who.user && row.customer.userId === who.user.id;
  // A manage token names a booking — or the first booking of a multi-service visit.
  const tokenSub = who.token ? await verifyBookingToken(who.token) : null;
  const tokenOk = !!tokenSub && (tokenSub === id || tokenSub === row.groupId);
  if (!ownerOk && !tokenOk) throw forbidden("You can't view this booking.");

  const salon = await db.salon.findUniqueOrThrow({
    where: { id: row.salon.id },
    select: { cancellationWindowHours: true, lateCancellationFeeBaisa: true, depositPolicy: true },
  });
  const { customer, ...booking } = row;
  return {
    booking: {
      ...booking,
      customer: { name: customer.name, phone: customer.phone, email: customer.email },
      balanceBaisa: Math.max(0, booking.priceBaisa - booking.paidBaisa),
      canCancel: ["PENDING", "CONFIRMED"].includes(booking.status) && booking.startTime > new Date(),
      // A multi-service visit is moved as a whole by the salon, not piece by piece online.
      canReschedule:
        !booking.groupId &&
        booking.salon.allowCustomerReschedule &&
        ["PENDING", "CONFIRMED"].includes(booking.status) &&
        booking.startTime > new Date(),
      canReview: booking.status === "COMPLETED" && !booking.review,
      cancellationQuote: quoteCancellation(booking, salon, false),
    },
    salonId: row.salon.id,
  };
}

export function assertCustomerCanReschedule(b: { canReschedule: boolean }) {
  if (!b.canReschedule) throw badRequest("This booking can't be rescheduled online. Please contact the salon.");
}
