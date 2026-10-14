import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";
import { rescheduleBooking } from "@/server/booking/engine";
import { afterResponse, loadSalonBooking } from "@/server/booking/access";
import { notifyBookingEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";

const schema = z.object({
  startTime: z.coerce.date(),
  staffId: z.string().uuid().nullable().optional(),
  note: z.string().trim().max(300).nullable().optional(),
  notifyCustomer: z.boolean().default(true),
});

/** Check availability → move → record old/new in history → notify. */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  await loadSalonBooking(ctx, id);
  const body = await parseBody(req, schema);
  const { booking, historyId, anchorId } = await rescheduleBooking({
    salonId: ctx.salonId,
    bookingId: id,
    startTime: body.startTime,
    staffId: body.staffId,
    changedById: ctx.user.id,
    enforceNotice: false,
    note: body.note,
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.rescheduled", entityType: "Booking", entityId: id, metadata: { to: body.startTime.toISOString() } });
  if (body.notifyCustomer) {
    afterResponse(() =>
      notifyBookingEvent(anchorId, "BOOKING_RESCHEDULED", { eventKey: historyId, notifySalon: true, actorUserId: ctx.user.id }),
    );
  }
  const full = await db.booking.findUniqueOrThrow({ where: { id: booking.id }, select: bookingSalonSelect });
  return ok(full, "Appointment moved ✨");
});
