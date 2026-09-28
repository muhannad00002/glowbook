import { z } from "zod";
import { db } from "@/lib/db";
import { forbidden, ok, parseBody, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";
import { changeStatus } from "@/server/booking/engine";
import { afterResponse, loadSalonBooking } from "@/server/booking/access";
import { notifyBookingEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";

const schema = z.object({
  status: z.enum(["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE", "COMPLETED", "NO_SHOW"]),
  note: z.string().trim().max(300).nullable().optional(),
});

const STAFF_MAY_SET = ["ARRIVED", "IN_SERVICE", "COMPLETED", "NO_SHOW"];

/** Arrived → In service → Completed, confirmations and no-shows. Artists may move their own. */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  const before = await loadSalonBooking(ctx, id);
  const body = await parseBody(req, schema);
  if (ctx.role === "STAFF" && !STAFF_MAY_SET.includes(body.status)) throw forbidden("Ask the front desk to change this.");
  const booking = await changeStatus({
    salonId: ctx.salonId,
    bookingId: id,
    to: body.status,
    changedById: ctx.user.id,
    note: body.note,
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.status", entityType: "Booking", entityId: id, metadata: { from: before.status, to: body.status } });

  if (before.status !== booking.status) {
    if (booking.status === "CONFIRMED" && before.status === "PENDING") {
      afterResponse(() => notifyBookingEvent(id, "BOOKING_CONFIRMED"));
    } else if (booking.status === "COMPLETED") {
      afterResponse(() => notifyBookingEvent(id, "BOOKING_COMPLETED"));
    }
  }
  const full = await db.booking.findUniqueOrThrow({ where: { id }, select: bookingSalonSelect });
  return ok(full);
});
