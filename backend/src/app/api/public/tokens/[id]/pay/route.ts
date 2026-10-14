import { ok, route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { startTokenPayment } from "@/server/seasonal/engine";
import { loadCustomerToken } from "@/server/seasonal/access";

/** Opens the checkout for the token's advance payment. */
export const POST = route(async (req, { id }) => {
  await loadCustomerToken(id, { user: await optionalUser(req), token: req.nextUrl.searchParams.get("token") });
  const t = await startTokenPayment(id);
  return ok({ amountBaisa: t.prepayBaisa, provider: t.paymentProvider, paymentRef: t.paymentRef, checkoutUrl: null }, null, 201);
});
