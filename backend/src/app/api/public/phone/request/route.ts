import { z } from "zod";
import { ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { requestOtp } from "@/server/otp";

const schema = z.object({ phone: phoneSchema, locale: z.enum(["en", "ar"]).default("en") });

/** Booking flow: send a 6-digit code to the customer's phone. */
export const POST = route(async (req) => {
  const { phone, locale } = await parseBody(req, schema);
  const { devCode } = await requestOtp(phone, locale, "booking");
  return ok({ phone, testCode: devCode ?? null }, "We've sent you a code.");
});
