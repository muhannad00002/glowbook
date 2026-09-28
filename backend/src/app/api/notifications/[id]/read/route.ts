import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";

export const POST = route(async (req, { id }) => {
  const user = await requireUser(req);
  await db.notification.updateMany({ where: { id, userId: user.id, readAt: null }, data: { readAt: new Date() } });
  return { read: true };
});
