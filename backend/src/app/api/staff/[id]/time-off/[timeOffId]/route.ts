import { db } from "@/lib/db";
import { notFound, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";

export const DELETE = route(async (req, { id, timeOffId }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const res = await db.staffTimeOff.deleteMany({ where: { id: timeOffId, staffId: id, salonId: ctx.salonId } });
  if (res.count === 0) throw notFound();
  return { deleted: true };
});
