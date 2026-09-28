import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { afterResponse, loadSalonBooking } from "@/server/booking/access";
import { recordDeskPayment } from "@/server/payments/service";
import { notifyBookingEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";

export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  await loadSalonBooking(ctx, id);
  return db.payment.findMany({ where: { bookingId: id, salonId: ctx.salonId }, orderBy: { createdAt: "asc" } });
});

const schema = z.object({
  amountBaisa: z.number().int().min(1).max(100_000_000),
  method: z.enum(["CASH", "CARD", "BANK_TRANSFER"]),
  kind: z.enum(["DEPOSIT", "BALANCE", "FULL", "CANCELLATION_FEE"]),
  notes: z.string().trim().max(300).nullable().optional(),
});

/** Record money taken at the desk. */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  await loadSalonBooking(ctx, id);
  const body = await parseBody(req, schema);
  const { payment, confirmed } = await recordDeskPayment({ ...body, salonId: ctx.salonId, bookingId: id, recordedById: ctx.user.id });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "payment.recorded", entityType: "Payment", entityId: payment.id, metadata: { amountBaisa: body.amountBaisa, method: body.method } });
  if (confirmed) afterResponse(() => notifyBookingEvent(id, "BOOKING_CONFIRMED"));
  return ok(payment, "Payment recorded.", 201);
});
