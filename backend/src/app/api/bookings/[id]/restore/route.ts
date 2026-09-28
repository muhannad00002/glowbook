import { db } from "@/lib/db";
import { ok, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";
import { restoreBooking } from "@/server/booking/engine";
import { loadSalonBooking } from "@/server/booking/access";
import { audit } from "@/server/audit";

/** "Undo" after a cancellation (within 15 minutes, if the slot is still free). */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  await loadSalonBooking(ctx, id);
  await restoreBooking({ salonId: ctx.salonId, bookingId: id, changedById: ctx.user.id });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.restored", entityType: "Booking", entityId: id });
  return ok(await db.booking.findUniqueOrThrow({ where: { id }, select: bookingSalonSelect }), "Cancellation undone.");
});
