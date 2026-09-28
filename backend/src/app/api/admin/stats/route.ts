import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireSuperAdmin } from "@/lib/auth/context";

export const GET = route(async (req) => {
  await requireSuperAdmin(req);
  const since = new Date(Date.now() - 30 * 86400_000);
  const [salons, activeSalons, users, bookings30, gmv] = await Promise.all([
    db.salon.count(),
    db.salon.count({ where: { bookings: { some: { createdAt: { gte: since } } } } }),
    db.user.count(),
    db.booking.count({ where: { createdAt: { gte: since } } }),
    db.payment.aggregate({ where: { status: "PAID", kind: { not: "REFUND" }, paidAt: { gte: since } }, _sum: { amountBaisa: true } }),
  ]);
  const byPlan = await db.salon.groupBy({ by: ["plan"], _count: { _all: true } });
  return {
    salons,
    activeSalons30d: activeSalons,
    users,
    bookings30d: bookings30,
    gmv30dBaisa: gmv._sum.amountBaisa ?? 0,
    byPlan: Object.fromEntries(byPlan.map((p) => [p.plan, p._count._all])),
  };
});
