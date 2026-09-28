import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { assertOwnedIds, checkShifts, staffInput } from "@/server/validation";
import { audit } from "@/server/audit";
import { staffDetail } from "@/server/staff";

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const rows = await db.staff.findMany({
    where: { salonId: ctx.salonId },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: {
      services: { select: { serviceId: true } },
      hours: { orderBy: [{ dayOfWeek: "asc" }, { startMinute: "asc" }] },
      user: { select: { id: true, email: true } },
    },
  });
  return rows.map(({ services, ...s }) => ({ ...s, serviceIds: services.map((x) => x.serviceId), hasLogin: !!s.userId }));
});

export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const { serviceIds, hours, ...body } = await parseBody(req, staffInput);
  if (serviceIds) await assertOwnedIds("service", ctx.salonId, serviceIds);
  if (hours) checkShifts(hours);

  // No shifts given → start from the salon's opening hours.
  const shifts =
    hours ??
    (await db.salonWorkingHour.findMany({ where: { salonId: ctx.salonId } })).map((h) => ({
      dayOfWeek: h.dayOfWeek,
      startMinute: h.openMinute,
      endMinute: h.closeMinute,
    }));

  const staff = await db.staff.create({
    data: {
      ...body,
      salonId: ctx.salonId,
      services: serviceIds ? { create: [...new Set(serviceIds)].map((serviceId) => ({ serviceId, salonId: ctx.salonId })) } : undefined,
      hours: { create: shifts.map((h) => ({ ...h, salonId: ctx.salonId })) },
    },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "staff.created", entityType: "Staff", entityId: staff.id });
  return ok(await staffDetail(ctx.salonId, staff.id), "Team member added 💕", 201);
});
