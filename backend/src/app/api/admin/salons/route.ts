import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireSuperAdmin } from "@/lib/auth/context";

/** Platform view of every tenant. Super admins only. */
export const GET = route(async (req) => {
  await requireSuperAdmin(req);
  const salons = await db.salon.findMany({
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      name: true,
      slug: true,
      city: true,
      category: true,
      isPublished: true,
      plan: true,
      subscriptionStatus: true,
      trialEndsAt: true,
      ratingAvg: true,
      ratingCount: true,
      createdAt: true,
      _count: { select: { bookings: true, staff: true, customers: true } },
    },
  });
  return salons.map(({ _count, ...s }) => ({ ...s, bookingCount: _count.bookings, staffCount: _count.staff, customerCount: _count.customers }));
});
