import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { categoryInput } from "@/server/validation";

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const rows = await db.serviceCategory.findMany({
    where: { salonId: ctx.salonId },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: { _count: { select: { services: { where: { deletedAt: null } } } } },
  });
  return rows.map(({ _count, ...c }) => ({ ...c, serviceCount: _count.services }));
});

export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, categoryInput);
  return ok(await db.serviceCategory.create({ data: { ...body, salonId: ctx.salonId } }), null, 201);
});
