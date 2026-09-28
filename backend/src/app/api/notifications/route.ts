import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";

const schema = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

/** The signed-in user's in-app inbox (customers and salon team alike). */
export const GET = route(async (req) => {
  const user = await requireUser(req);
  const q = parseQuery(req, schema);
  const [rows, unread] = await Promise.all([
    db.notification.findMany({
      where: { userId: user.id, channel: "IN_APP" },
      select: { id: true, type: true, title: true, body: true, bookingId: true, salonId: true, readAt: true, createdAt: true },
      orderBy: { createdAt: "desc" },
      take: q.limit + 1,
      ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    }),
    db.notification.count({ where: { userId: user.id, channel: "IN_APP", readAt: null } }),
  ]);
  return { items: rows.slice(0, q.limit), unread, nextCursor: rows.length > q.limit ? rows[q.limit - 1].id : null };
});
