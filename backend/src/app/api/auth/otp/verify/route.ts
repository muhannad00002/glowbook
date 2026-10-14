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
  // Needed only when this phone has no account yet.
  name: z.string().trim().min(2).max(80).optional(),
  locale: z.enum(["en", "ar"]).default("en"),
});

/** Phone sign-in, step 2: verify the code, then sign in (or create the account). */
export const POST = route(async (req) => {
  const { phone, code, name, locale } = await parseBody(req, schema);

  // Ask for the name before consuming the code, so she doesn't need a new one.
  let user = await db.user.findUnique({ where: { phone } });
  if (!user && !name) throw badRequest("Please tell us your name to create your account.", { needsName: true });

  await verifyOtp(phone, code);

  if (!user) {
    user = await db.user.create({ data: { phone, name: name!, locale, phoneVerifiedAt: new Date() } });
  } else if (!user.phoneVerifiedAt) {
    user = await db.user.update({ where: { id: user.id }, data: { phoneVerifiedAt: new Date() } });
  }
  if (!user.isActive) throw badRequest("This account is disabled.");

  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return authPayload(user.id, tokens);
});
