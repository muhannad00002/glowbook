import { z } from "zod";
import { db } from "@/lib/db";
import { parseBody, route, unauthorized } from "@/lib/http";
import { verifyPassword } from "@/lib/auth/password";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";

const schema = z.object({
  // Email or phone number.
  identifier: z.string().trim().min(3),
  password: z.string().min(1),
});

// A fixed hash so unknown accounts cost the same bcrypt time as known ones.
const DUMMY_HASH = "$2b$11$c3iMbmPL9MYassAZcbM6.umJyIUHYCfcmbEEnkC/O75GC16g00iRq";

export const POST = route(async (req) => {
  const { identifier, password } = await parseBody(req, schema);
  const isEmail = identifier.includes("@");
  const user = await db.user.findFirst({
    where: isEmail ? { email: identifier.toLowerCase() } : { phone: identifier.replace(/[\s\-()]/g, "") },
  });
  const valid = await verifyPassword(password, user?.passwordHash ?? DUMMY_HASH);
  if (!user || !user.passwordHash || !valid || !user.isActive) {
    throw unauthorized("Incorrect email or password.");
  }
  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return authPayload(user.id, tokens);
});
