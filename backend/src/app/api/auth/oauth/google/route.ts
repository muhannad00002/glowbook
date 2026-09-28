import { z } from "zod";
import { parseBody, route, unauthorized } from "@/lib/http";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";
import { signInWithIdToken } from "@/server/oauth";

const schema = z.object({ idToken: z.string().min(20) });

export const POST = route(async (req) => {
  const { idToken } = await parseBody(req, schema);
  const user = await signInWithIdToken("google", idToken);
  if (!user.isActive) throw unauthorized("This account is disabled.");
  return authPayload(user.id, await issueSession(user.id, req.headers.get("user-agent")));
});
