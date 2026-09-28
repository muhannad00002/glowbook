import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { bookingCustomerSelect } from "@/server/dto";

const schema = z.object({ scope: z.enum(["upcoming", "past", "all"]).default("upcoming") });

/** The signed-in customer's appointments across every salon. */
export const GET = route(async (req) => {
  const user = await requireUser(req);
  const { scope } = parseQuery(req, schema);
  const now = new Date();
  const rows = await db.booking.findMany({
    where: {
      customer: { userId: user.id },
      ...(scope === "upcoming"
        ? { startTime: { gte: new Date(now.getTime() - 3 * 3600_000) }, status: { in: ["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE"] } }
        : scope === "past"
          ? { OR: [{ startTime: { lt: now } }, { status: { in: ["COMPLETED", "CANCELLED", "NO_SHOW"] } }] }
          : {}),
    },
    select: bookingCustomerSelect,
    orderBy: { startTime: scope === "upcoming" ? "asc" : "desc" },
    take: 100,
  });
  return rows.map((b) => ({
    ...b,
    balanceBaisa: Math.max(0, b.priceBaisa - b.paidBaisa),
    canReview: b.status === "COMPLETED" && !b.review,
  }));
});
