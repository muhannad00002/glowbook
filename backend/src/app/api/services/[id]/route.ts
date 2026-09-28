import { db } from "@/lib/db";
import { notFound, ok, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { serviceSelect } from "@/server/dto";
import { assertOwnedIds, checkDeposit, serviceInput } from "@/server/validation";
import { audit } from "@/server/audit";

async function load(salonId: string, id: string) {
  const service = await db.service.findFirst({
    where: { id, salonId, deletedAt: null },
    select: { ...serviceSelect, staff: { select: { staffId: true } } },
  });
  if (!service) throw notFound("Service not found.");
  const { staff, ...rest } = service;
  return { ...rest, staffIds: staff.map((s) => s.staffId) };
}

export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  return load(ctx.salonId, id);
});

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const current = await load(ctx.salonId, id);
  const { staffIds, ...body } = await parsePatch(req, serviceInput);
  checkDeposit({ ...current, ...body });
  if (body.categoryId) await assertOwnedIds("serviceCategory", ctx.salonId, [body.categoryId]);
  if (staffIds) await assertOwnedIds("staff", ctx.salonId, staffIds);

  await db.$transaction(async (tx) => {
    const requirement = body.paymentRequirement ?? current.paymentRequirement;
    await tx.service.update({
      where: { id },
      data: { ...body, ...(requirement !== "DEPOSIT" ? { depositBaisa: 0 } : {}) },
    });
    if (staffIds) {
      await tx.staffService.deleteMany({ where: { serviceId: id } });
      await tx.staffService.createMany({ data: [...new Set(staffIds)].map((staffId) => ({ staffId, serviceId: id, salonId: ctx.salonId })) });
    }
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "service.updated", entityType: "Service", entityId: id, metadata: { fields: Object.keys(body) } });
  return load(ctx.salonId, id);
});

/** Soft delete: past bookings keep pointing at it; it disappears from menus. */
export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await load(ctx.salonId, id);
  await db.service.update({ where: { id }, data: { deletedAt: new Date(), isActive: false } });
  await db.staffService.deleteMany({ where: { serviceId: id } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "service.deleted", entityType: "Service", entityId: id });
  return ok({ deleted: true }, "Service removed.");
});
