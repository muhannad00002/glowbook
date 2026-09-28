import { z } from "zod";
import { randomInt } from "node:crypto";
import { db } from "@/lib/db";
import { ApiError, ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { sha256 } from "@/lib/auth/tokens";
import { sendAccountMessage } from "@/server/notifications/service";
import { providers } from "@/server/notifications/providers";

const schema = z.object({ phone: phoneSchema, locale: z.enum(["en", "ar"]).default("en") });

/** Phone sign-in, step 1: text a 6-digit code (SMS, or WhatsApp if SMS isn't set up). */
export const POST = route(async (req) => {
  const { phone, locale } = await parseBody(req, schema);

  const lastHour = await db.otpCode.count({
    where: { phone, createdAt: { gte: new Date(Date.now() - 3600_000) } },
  });
  if (lastHour >= 5) throw new ApiError(429, "Too many codes requested. Please try again later.");

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  await db.otpCode.create({
    data: { phone, codeHash: sha256(`${phone}:${code}`), expiresAt: new Date(Date.now() + 10 * 60_000) },
  });

  const channel = providers.SMS.isConfigured() ? "SMS" : providers.WHATSAPP.isConfigured() ? "WHATSAPP" : null;
  if (channel) {
    await sendAccountMessage({ type: "PHONE_OTP", channel, to: phone, locale, variables: { code } });
  } else if (process.env.NODE_ENV === "production") {
    throw new ApiError(503, "Phone sign-in isn't available right now. Please use email.");
  }

  const dev = !channel && process.env.NODE_ENV !== "production";
  if (dev) console.info(`[otp] ${phone} → ${code}`);
  return ok(dev ? { devCode: code } : null, "We've sent you a code.");
});
