import { z } from "zod";
import { db } from "@/lib/db";
import { parseBody, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";

const schema = z.object({
  token: z.string().min(20).max(4096),
  platform: z.enum(["ios", "android", "web"]),
});

/** Registers an FCM device token so push notifications can reach this device. */
export const POST = route(async (req) => {
  const user = await requireUser(req);
  const { token, platform } = await parseBody(req, schema);
  await db.deviceToken.upsert({
    where: { token },
    create: { token, platform, userId: user.id },
    update: { userId: user.id, platform, lastSeenAt: new Date() },
  });
  return { registered: true };
});

export const DELETE = route(async (req) => {
  const user = await requireUser(req);
  const { token } = await parseBody(req, schema.pick({ token: true }));
  await db.deviceToken.deleteMany({ where: { token, userId: user.id } });
  return { removed: true };
});
