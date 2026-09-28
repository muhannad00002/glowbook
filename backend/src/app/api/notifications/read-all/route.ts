import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";

export const POST = route(async (req) => {
  const user = await requireUser(req);
  const res = await db.notification.updateMany({
    where: { userId: user.id, channel: "IN_APP", readAt: null },
    data: { readAt: new Date() },
  });
  return { marked: res.count };
});
