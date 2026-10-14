import { z } from "zod";
import { ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { requestOtp } from "@/server/otp";

const schema = z.object({ phone: phoneSchema, locale: z.enum(["en", "ar"]).default("en") });

/** Phone sign-in, step 1: text a 6-digit code (SMS, or WhatsApp if SMS isn't set up). */
export const POST = route(async (req) => {
  const { phone, locale } = await parseBody(req, schema);
  const { devCode } = await requestOtp(phone, locale, "signin");
  return ok(devCode ? { devCode } : null, "We've sent you a code.");
});
