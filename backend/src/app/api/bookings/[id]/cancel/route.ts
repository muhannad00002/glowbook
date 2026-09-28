import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";
import { cancelBooking } from "@/server/booking/engine";
import { afterResponse, loadSalonBooking } from "@/server/booking/access";
import { notifyBookingEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";

const schema = z.object({
  reason: z.string().trim().max(300).nullable().optional(),
  notifyCustomer: z.boolean().default(true),
});

/** Salon-initiated cancellation: always free for the client, deposit refunded. */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  await loadSalonBooking(ctx, id);
  const body = await parseBody(req, schema);
  const { booking, quote } = await cancelBooking({
    salonId: ctx.salonId,
    bookingId: id,
    cancelledById: ctx.user.id,
    bySalon: true,
    reason: body.reason,
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.cancelled", entityType: "Booking", entityId: id, metadata: { reason: body.reason ?? null } });
  if (body.notifyCustomer) {
    afterResponse(() => notifyBookingEvent(id, "BOOKING_CANCELLED", { notifySalon: true, actorUserId: ctx.user.id }));
  }
  const full = await db.booking.findUniqueOrThrow({ where: { id: booking.id }, select: bookingSalonSelect });
  return ok({ booking: full, quote, undoUntil: new Date(Date.now() + 15 * 60_000).toISOString() }, "Appointment cancelled.");
});
