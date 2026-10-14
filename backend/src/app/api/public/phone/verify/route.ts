import { z } from "zod";
import { ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { signPhoneToken } from "@/lib/auth/tokens";
import { verifyOtp } from "@/server/otp";

const schema = z.object({
  phone: phoneSchema,
  code: z.string().regex(/^\d{6}$/, "Enter the 6-digit code."),
});

/**
 * Booking flow: check the code and return a short-lived phone token. No account or
 * session is created — the token only proves this phone for the booking request.
 */
export const POST = route(async (req) => {
  const { phone, code } = await parseBody(req, schema);
  await verifyOtp(phone, code);
  return ok({ phone, phoneToken: await signPhoneToken(phone), expiresIn: 30 * 60 });
});
