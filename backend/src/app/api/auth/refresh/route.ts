import { z } from "zod";
import { parseBody, route, unauthorized } from "@/lib/http";
import { rotateSession } from "@/lib/auth/tokens";

const schema = z.object({ refreshToken: z.string().min(10) });

export const POST = route(async (req) => {
  const { refreshToken } = await parseBody(req, schema);
  const tokens = await rotateSession(refreshToken, req.headers.get("user-agent"));
  if (!tokens) throw unauthorized("Your session has expired. Please sign in again.");
  return tokens;
});
