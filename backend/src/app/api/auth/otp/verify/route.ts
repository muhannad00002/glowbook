import { z } from "zod";
import { timingSafeEqual } from "node:crypto";
import { db } from "@/lib/db";
import { badRequest, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { issueSession, sha256 } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";

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

  const otp = await db.otpCode.findFirst({
    where: { phone, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: "desc" },
  });
  if (!otp || otp.attempts >= 5) throw badRequest("This code has expired. Please request a new one.");

  const expected = Buffer.from(otp.codeHash);
  const given = Buffer.from(sha256(`${phone}:${code}`));
  if (!timingSafeEqual(expected, given)) {
    await db.otpCode.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    throw badRequest("That code isn't right. Please try again.");
  }
  await db.otpCode.update({ where: { id: otp.id }, data: { consumedAt: new Date() } });

  let user = await db.user.findUnique({ where: { phone } });
  if (!user) {
    if (!name) throw badRequest("Please tell us your name to create your account.", { needsName: true });
    user = await db.user.create({ data: { phone, name, locale, phoneVerifiedAt: new Date() } });
  } else if (!user.phoneVerifiedAt) {
    user = await db.user.update({ where: { id: user.id }, data: { phoneVerifiedAt: new Date() } });
  }
  if (!user.isActive) throw badRequest("This account is disabled.");

  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return authPayload(user.id, tokens);
});
