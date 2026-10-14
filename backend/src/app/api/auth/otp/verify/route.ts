import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";
import { verifyOtp } from "@/server/otp";

const schema = z.object({
  phone: phoneSchema,
  code: z.string().regex(/^\d{6}$/, "Enter the 6-digit code."),
});

/** Team phone sign-in, step 2: verify the code, then sign in. */
export const POST = route(async (req) => {
  const { phone, code } = await parseBody(req, schema);

  // Team sign-in only — a phone without a staff account never gets one created here.
  let user = await db.user.findUnique({ where: { phone } });
  if (!user) throw badRequest("No team account uses this number.");

  await verifyOtp(phone, code);

  if (!user.phoneVerifiedAt) {
    user = await db.user.update({ where: { id: user.id }, data: { phoneVerifiedAt: new Date() } });
  }
  if (!user.isActive) throw badRequest("This account is disabled.");

  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return authPayload(user.id, tokens);
});
