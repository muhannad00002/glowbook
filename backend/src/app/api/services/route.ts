import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { serviceSelect } from "@/server/dto";
import { assertOwnedIds, checkDeposit, serviceInput } from "@/server/validation";
import { audit } from "@/server/audit";

const querySchema = z.object({
  categoryId: z.string().uuid().optional(),
  includeInactive: z.enum(["true", "false"]).default("true"),
});

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const q = parseQuery(req, querySchema);
  const rows = await db.service.findMany({
    where: {
      salonId: ctx.salonId,
      deletedAt: null,
      ...(q.categoryId ? { categoryId: q.categoryId } : {}),
      ...(q.includeInactive === "false" ? { isActive: true } : {}),
    },
    select: {
      ...serviceSelect,
      category: { select: { id: true, name: true, nameAr: true } },
      staff: { select: { staffId: true } },
      _count: { select: { bookings: true } },
    },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
  });
  return rows.map(({ staff, _count, ...s }) => ({ ...s, staffIds: staff.map((x) => x.staffId), bookingCount: _count.bookings }));
});

export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const { staffIds, ...body } = await parseBody(req, serviceInput);
  checkDeposit(body);
  if (body.categoryId) await assertOwnedIds("serviceCategory", ctx.salonId, [body.categoryId]);
  if (staffIds) await assertOwnedIds("staff", ctx.salonId, staffIds);

  const service = await db.service.create({
    data: {
      ...body,
      depositBaisa: body.paymentRequirement === "DEPOSIT" ? body.depositBaisa : 0,
      salonId: ctx.salonId,
      staff: staffIds ? { create: [...new Set(staffIds)].map((staffId) => ({ staffId, salonId: ctx.salonId })) } : undefined,
    },
    select: serviceSelect,
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "service.created", entityType: "Service", entityId: service.id });
  return ok({ ...service, staffIds: staffIds ?? [] }, "Service added ✨", 201);
});
