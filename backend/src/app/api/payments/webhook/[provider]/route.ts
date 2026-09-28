import { fail, route } from "@/lib/http";

/**
 * Gateway webhooks land here: /api/payments/webhook/<provider>.
 *
 * Integration checklist for a real gateway (Thawani, Stripe, …):
 *  1. Verify the request signature with the provider's secret (env var).
 *  2. Look up the Payment by `providerRef`.
 *  3. Call `markOnlinePaymentPaid(payment.id)` — it is idempotent and confirms the
 *     booking when its deposit is covered — then `notifyBookingEvent(..., "BOOKING_CONFIRMED")`.
 * No provider is wired yet, so every call is rejected.
 */
export const POST = route(async (_req, { provider }) => fail(400, `No payment provider named "${provider}" is configured.`));
