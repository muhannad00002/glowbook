import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, notFound, ok, parseBody, route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { afterResponse } from "@/server/booking/access";
import { markTokenPaid } from "@/server/seasonal/engine";
import { loadCustomerToken } from "@/server/seasonal/access";
import { notifyTokenEvent } from "@/server/notifications/service";

/**
 * Sandbox checkout completion for tokens. Exists ONLY when PAYMENT_PROVIDER=test — a
 * real gateway's webhook plays this role in production. No money moves.
 */
export const POST = route(async (req, { id }) => {
  if (process.env.PAYMENT_PROVIDER !== "test") throw notFound();
  const body = await parseBody(req, z.object({ succeed: z.boolean().default(true) }));
  const who = { user: await optionalUser(req), token: req.nextUrl.searchParams.get("token") };
  await loadCustomerToken(id, who);
  const row = await db.seasonalToken.findUnique({ where: { id }, select: { paymentProvider: true } });
  if (row?.paymentProvider !== "test") throw badRequest("Start the payment first.");
  if (!body.succeed) throw badRequest("The test payment was declined.");
  const { confirmed } = await markTokenPaid(id);
  if (confirmed) afterResponse(() => notifyTokenEvent(id, "TOKEN_CONFIRMED", { notifySalon: true }));
  return ok({ token: await loadCustomerToken(id, who), confirmed }, "Payment received — your token is confirmed 🎟️");
});
