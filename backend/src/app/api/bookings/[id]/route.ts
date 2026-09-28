import { z } from "zod";
import { db } from "@/lib/db";
import { forbidden, parsePatch, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { bookingSalonSelect } from "@/server/dto";
import { loadSalonBooking } from "@/server/booking/access";
import { quoteCancellation } from "@/server/booking/engine";
import { audit } from "@/server/audit";

/** Booking detail for the team: history, payments and the client's private notes. */
export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  const booking = await loadSalonBooking(ctx, id);
  const [history, payments, customer, salon] = await Promise.all([
    db.bookingStatusHistory.findMany({ where: { bookingId: id }, orderBy: { createdAt: "asc" } }),
    db.payment.findMany({ where: { bookingId: id }, orderBy: { createdAt: "asc" } }),
    db.customer.findUniqueOrThrow({
      where: { id: booking.customerId },
      select: { id: true, name: true, phone: true, email: true, notes: true, birthday: true },
    }),
    db.salon.findUniqueOrThrow({ where: { id: ctx.salonId } }),
  ]);
  const actorIds = [...new Set(history.map((h) => h.changedById).filter((x): x is string => !!x))];
  const actors = await db.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true } });
  const names = new Map(actors.map((a) => [a.id, a.name]));
  const staffIds = [...new Set(history.flatMap((h) => [h.oldStaffId, h.newStaffId]).filter((x): x is string => !!x))];
  const staff = await db.staff.findMany({ where: { id: { in: staffIds }, salonId: ctx.salonId }, select: { id: true, name: true } });
  const staffNames = new Map(staff.map((s) => [s.id, s.name]));

  return {
    ...booking,
    customer,
    history: history.map((h) => ({
      ...h,
      changedByName: h.changedById ? (names.get(h.changedById) ?? null) : null,
      oldStaffName: h.oldStaffId ? (staffNames.get(h.oldStaffId) ?? null) : null,
      newStaffName: h.newStaffId ? (staffNames.get(h.newStaffId) ?? null) : null,
    })),
    payments,
    cancellationQuote: quoteCancellation(booking, salon, true),
    balanceBaisa: Math.max(0, booking.priceBaisa - booking.paidBaisa),
  };
});

const patchSchema = z.object({
  internalNotes: z.string().trim().max(2000).nullable(),
  customerNotes: z.string().trim().max(1000).nullable(),
});

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  await loadSalonBooking(ctx, id);
  const body = await parsePatch(req, patchSchema);
  if (ctx.role === "STAFF" && body.customerNotes !== undefined) throw forbidden("Only the front desk can edit client notes.");
  await db.booking.update({ where: { id }, data: body });
  if (body.internalNotes !== undefined) {
    await db.bookingStatusHistory.create({
      data: { salonId: ctx.salonId, bookingId: id, kind: "NOTE", changedById: ctx.user.id, note: "Notes updated" },
    });
  }
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "booking.notes.updated", entityType: "Booking", entityId: id });
  return db.booking.findUniqueOrThrow({ where: { id }, select: bookingSalonSelect });
});
