import { db } from "@/lib/db";
import { notFound, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { categoryInput } from "@/server/validation";

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parsePatch(req, categoryInput);
  const res = await db.serviceCategory.updateMany({ where: { id, salonId: ctx.salonId }, data: body });
  if (res.count === 0) throw notFound("Category not found.");
  return db.serviceCategory.findUniqueOrThrow({ where: { id } });
});

/** Services in the category become uncategorised (FK is SET NULL). */
export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const res = await db.serviceCategory.deleteMany({ where: { id, salonId: ctx.salonId } });
  if (res.count === 0) throw notFound("Category not found.");
  return { deleted: true };
});
