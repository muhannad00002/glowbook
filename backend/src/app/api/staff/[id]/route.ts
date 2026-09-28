import { db } from "@/lib/db";
import { conflict, forbidden, ok, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { assertOwnedIds, checkShifts, staffInput } from "@/server/validation";
import { audit } from "@/server/audit";
import { staffDetail } from "@/server/staff";

export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  if (ctx.role === "STAFF" && ctx.staffId !== id) throw forbidden();
  return staffDetail(ctx.salonId, id);
});

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await staffDetail(ctx.salonId, id);
  const { serviceIds, hours, ...body } = await parsePatch(req, staffInput);
  if (serviceIds) await assertOwnedIds("service", ctx.salonId, serviceIds);
  if (hours) checkShifts(hours);

  await db.$transaction(async (tx) => {
    await tx.staff.update({ where: { id }, data: body });
    if (serviceIds) {
      await tx.staffService.deleteMany({ where: { staffId: id } });
      await tx.staffService.createMany({ data: [...new Set(serviceIds)].map((serviceId) => ({ serviceId, staffId: id, salonId: ctx.salonId })) });
    }
    if (hours) {
      await tx.staffWorkingHour.deleteMany({ where: { staffId: id } });
      await tx.staffWorkingHour.createMany({ data: hours.map((h) => ({ ...h, staffId: id, salonId: ctx.salonId })) });
    }
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "staff.updated", entityType: "Staff", entityId: id, metadata: { fields: Object.keys(body) } });
  return staffDetail(ctx.salonId, id);
});

/**
 * Staff with booking history are deactivated rather than deleted, so the history stays
 * intact. Deactivated staff disappear from availability immediately.
 */
export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await staffDetail(ctx.salonId, id);
  const upcoming = await db.booking.count({
    where: { staffId: id, startTime: { gte: new Date() }, status: { in: ["PENDING", "CONFIRMED"] } },
  });
  if (upcoming > 0) throw conflict(`She still has ${upcoming} upcoming booking(s). Reassign or cancel them first.`);
  const history = await db.booking.count({ where: { staffId: id } });
  if (history > 0) {
    await db.staff.update({ where: { id }, data: { isActive: false } });
    await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "staff.deactivated", entityType: "Staff", entityId: id });
    return ok({ deactivated: true }, "Deactivated — past bookings are kept.");
  }
  await db.staff.delete({ where: { id } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "staff.deleted", entityType: "Staff", entityId: id });
  return ok({ deleted: true }, "Team member removed.");
});
