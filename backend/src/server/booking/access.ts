import { after } from "next/server";
import { db } from "@/lib/db";
import { forbidden, notFound } from "@/lib/http";
import type { SalonContext } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";

/** Loads a booking the caller may see: salon-scoped, and own-only for STAFF. */
export async function loadSalonBooking(ctx: SalonContext, id: string) {
  const booking = await db.booking.findFirst({ where: { id, salonId: ctx.salonId }, select: bookingSalonSelect });
  if (!booking) throw notFound("Booking not found.");
  if (ctx.role === "STAFF" && booking.staffId !== ctx.staffId) throw forbidden();
  return booking;
}

/** Run side effects (notifications) after the response is sent. */
export function afterResponse(fn: () => Promise<unknown>) {
  after(async () => {
    try {
      await fn();
    } catch (e) {
      console.error("[after] side effect failed", e);
    }
  });
}
