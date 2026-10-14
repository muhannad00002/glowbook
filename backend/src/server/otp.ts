import { randomInt, timingSafeEqual } from "node:crypto";
import { db } from "@/lib/db";
import { ApiError, badRequest } from "@/lib/http";
import { sha256 } from "@/lib/auth/tokens";
import { sendAccountMessage } from "@/server/notifications/service";
import { providers } from "@/server/notifications/providers";

/**
 * One-time codes sent to a phone (SMS, or WhatsApp when SMS isn't set up).
 *
 * Purposes:
 *  - "signin": proves ownership of an account's phone → a full session. Codes are only
 *    ever revealed in local development, never in production.
 *  - "booking": proves the customer's phone before a booking → a short-lived phone
 *    token, no session. With OTP_TEST_MODE=true the code is returned to the client so a
 *    demo deployment works before an SMS provider is connected (a leaked code can then
 *    only book under that phone — it can't take over an account).
 */
export type OtpPurpose = "signin" | "booking";

const CODE_TTL_MS = 10 * 60_000;
const MAX_PER_HOUR = 5;
const MAX_ATTEMPTS = 5;

function deliveryChannel() {
  return providers.SMS.isConfigured() ? "SMS" : providers.WHATSAPP.isConfigured() ? "WHATSAPP" : null;
}

function revealCode(purpose: OtpPurpose, channel: string | null) {
  if (channel) return false;
  if (process.env.NODE_ENV !== "production") return true;
  return purpose === "booking" && process.env.OTP_TEST_MODE === "true";
}

/** Sends a code. Returns it only when it may be revealed (development / booking test mode). */
export async function requestOtp(phone: string, locale: string, purpose: OtpPurpose): Promise<{ devCode?: string }> {
  const lastHour = await db.otpCode.count({ where: { phone, createdAt: { gte: new Date(Date.now() - 3600_000) } } });
  if (lastHour >= MAX_PER_HOUR) throw new ApiError(429, "Too many codes requested. Please try again later.");

  const channel = deliveryChannel();
  const reveal = revealCode(purpose, channel);
  if (!channel && !reveal) {
    throw new ApiError(503, purpose === "signin" ? "Phone sign-in isn't available right now. Please use email." : "We can't send verification codes right now. Please contact the salon.");
  }

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  await db.otpCode.create({ data: { phone, codeHash: sha256(`${phone}:${code}`), expiresAt: new Date(Date.now() + CODE_TTL_MS) } });

  if (channel) {
    await sendAccountMessage({ type: "PHONE_OTP", channel, to: phone, locale, variables: { code } });
    return {};
  }
  console.info(`[otp:${purpose}] ${phone} → ${code}`);
  return { devCode: code };
}

/** Checks and consumes the latest code for this phone. Throws a friendly 400 otherwise. */
export async function verifyOtp(phone: string, code: string): Promise<void> {
  const otp = await db.otpCode.findFirst({
    where: { phone, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: "desc" },
  });
  if (!otp || otp.attempts >= MAX_ATTEMPTS) throw badRequest("This code has expired. Please request a new one.", { expired: true });

  const expected = Buffer.from(otp.codeHash);
  const given = Buffer.from(sha256(`${phone}:${code}`));
  if (!timingSafeEqual(expected, given)) {
    await db.otpCode.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    throw badRequest("That code isn't right. Please try again.");
  }
  // Consume atomically so the same code can't be used twice in parallel.
  const res = await db.otpCode.updateMany({ where: { id: otp.id, consumedAt: null }, data: { consumedAt: new Date() } });
  if (res.count !== 1) throw badRequest("This code has already been used. Please request a new one.", { expired: true });
}
