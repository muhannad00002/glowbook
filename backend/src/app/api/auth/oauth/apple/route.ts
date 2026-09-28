import { z } from "zod";
import { parseBody, route, unauthorized } from "@/lib/http";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";
import { signInWithIdToken } from "@/server/oauth";

// Apple only sends the user's name on the very first authorization, from the device.
const schema = z.object({ idToken: z.string().min(20), name: z.string().trim().max(80).optional() });

export const POST = route(async (req) => {
  const { idToken, name } = await parseBody(req, schema);
  const user = await signInWithIdToken("apple", idToken, name);
  if (!user.isActive) throw unauthorized("This account is disabled.");
  return authPayload(user.id, await issueSession(user.id, req.headers.get("user-agent")));
});
