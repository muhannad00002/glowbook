import { db } from "@/lib/db";
import { forbidden, notFound, route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";

export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  const row = await db.blockedTime.findFirst({ where: { id, salonId: ctx.salonId } });
  if (!row) throw notFound();
  if (ctx.role === "STAFF" && row.staffId !== ctx.staffId) throw forbidden();
  if (ctx.role === "RECEPTIONIST" && row.staffId === null) throw forbidden();
  await db.blockedTime.delete({ where: { id } });
  return { deleted: true };
});
