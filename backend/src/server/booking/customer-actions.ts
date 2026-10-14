import { db } from "@/lib/db";
import { badRequest, forbidden, gone, LINK_GRACE_MS, notFound } from "@/lib/http";
import type { AuthUser } from "@/lib/auth/context";
import { verifyBookingToken } from "@/lib/auth/tokens";
import { bookingCustomerSelect } from "@/server/dto";
import { quoteCancellation } from "./engine";

/**
 * Customer-side access to a booking. Customers have no accounts: the signed link sent
 * after booking is the only key, and it works until a day after the visit ends.
 */
export async function loadCustomerBooking(id: string, who: { user?: AuthUser | null; token?: string | null }) {
  const row = await db.booking.findUnique({
    where: { id },
    select: { ...bookingCustomerSelect, customer: { select: { userId: true, name: true, phone: true, email: true } } },
  });
  if (!row) throw notFound("Booking not found.");

  // A manage token names a booking — or the first booking of a multi-service visit.
  const tokenSub = who.token ? await verifyBookingToken(who.token) : null;
  const tokenOk = !!tokenSub && (tokenSub === id || tokenSub === row.groupId);
  if (!tokenOk) throw forbidden("This link isn't valid. Please use the link we sent you.");

  const salon = await db.salon.findUniqueOrThrow({
    where: { id: row.salon.id },
    select: { cancellationWindowHours: true, lateCancellationFeeBaisa: true, depositPolicy: true },
  });
  const { customer, ...booking } = row;
  const parts = row.groupId
    ? await db.booking.findMany({
        where: { groupId: row.groupId, status: { notIn: ["CANCELLED", "NO_SHOW"] } },
        orderBy: { startTime: "asc" },
        select: { id: true, startTime: true, endTime: true, priceBaisa: true, depositBaisa: true, paidBaisa: true, service: { select: { id: true, name: true, nameAr: true, durationMinutes: true } } },
      })
    : [];
  const visitEnd = parts.length > 1 ? parts[parts.length - 1].endTime : row.endTime;
  if (Date.now() > visitEnd.getTime() + LINK_GRACE_MS) throw gone("This link has expired.");
  const visit =
    parts.length > 1
      ? {
          bookingIds: parts.map((p) => p.id),
          services: parts.map((p) => p.service),
          serviceIds: parts.map((p) => p.service.id),
          startTime: parts[0].startTime,
          endTime: parts[parts.length - 1].endTime,
          priceBaisa: parts.reduce((sum, p) => sum + p.priceBaisa, 0),
          depositBaisa: parts.reduce((sum, p) => sum + p.depositBaisa, 0),
          paidBaisa: parts.reduce((sum, p) => sum + p.paidBaisa, 0),
        }
      : null;
  return {
    booking: {
      ...booking,
      visit,
      customer: { name: customer.name, phone: customer.phone, email: customer.email },
      balanceBaisa: Math.max(0, booking.priceBaisa - booking.paidBaisa),
      canCancel: ["PENDING", "CONFIRMED"].includes(booking.status) && booking.startTime > new Date(),
      // A multi-service visit is moved as a whole (see rescheduleBooking).
      canReschedule:
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
