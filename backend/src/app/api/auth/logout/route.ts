import { z } from "zod";
import { db } from "@/lib/db";
import { parseBody, route } from "@/lib/http";
import { revokeSession } from "@/lib/auth/tokens";
import { optionalUser } from "@/lib/auth/context";

const schema = z.object({ refreshToken: z.string().min(10), deviceToken: z.string().optional() });

export const POST = route(async (req) => {
  const { refreshToken, deviceToken } = await parseBody(req, schema);
  await revokeSession(refreshToken);
  const user = await optionalUser(req);
  if (user && deviceToken) await db.deviceToken.deleteMany({ where: { userId: user.id, token: deviceToken } });
  return { loggedOut: true };
});
