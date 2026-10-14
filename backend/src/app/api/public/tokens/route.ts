import { z } from "zod";
import { badRequest, ok, parseBody, route } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { signSeasonalToken } from "@/lib/auth/tokens";
import { resolveCustomer } from "@/server/customers";
import { activeGateway } from "@/server/payments/service";
import { createTokenHold, loadOffering, TOKEN_HOLD_MINUTES } from "@/server/seasonal/engine";
import { loadCustomerToken, requireVerifiedPhone } from "@/server/seasonal/access";
import { audit } from "@/server/audit";

const schema = z.object({
  offeringId: z.string().uuid(),
  startTime: z.coerce.date(),
  customer: z.object({
    name: z.string().trim().min(2, "Please enter your name.").max(80),
    phone: phoneSchema,
    email: z.string().trim().toLowerCase().email().optional().or(z.literal("").transform(() => undefined)),
  }),
  notes: z.string().trim().max(500).optional(),
  phoneToken: z.string().optional(),
});

/**
 * Take a seasonal token. The phone must be verified, exactly like a booking. The token
 * is held (PENDING_PAYMENT) until the advance payment arrives — see /pay.
 */
export const POST = route(async (req) => {
  const body = await parseBody(req, schema);
  const offering = await loadOffering(body.offeringId);
  const salon = offering.event.salon;
  if (!salon.isPublished) throw badRequest("This salon isn't taking online bookings.");
  if (!activeGateway()) throw badRequest("Online payment isn't available yet, so tokens can't be booked online. Please contact the salon.");
  const verifiedPhone = await requireVerifiedPhone(body.customer.phone, body.phoneToken);

  const customer = await resolveCustomer({
    salonId: salon.id,
    verifiedPhone,
    name: body.customer.name,
    phone: body.customer.phone,
    email: body.customer.email,
    source: "PUBLIC_PAGE",
  });
  const hold = await createTokenHold({ offeringId: offering.id, startTime: body.startTime, customerId: customer.id, notes: body.notes });
  await audit({ req, salonId: salon.id, action: "token.held", entityType: "SeasonalToken", entityId: hold.id, metadata: { number: hold.number } });

  const accessToken = await signSeasonalToken(hold.id);
  return ok(
    { token: await loadCustomerToken(hold.id, { token: accessToken }), accessToken, holdMinutes: TOKEN_HOLD_MINUTES },
    `Token #${hold.number} is held for ${TOKEN_HOLD_MINUTES} minutes — pay to confirm it.`,
    201,
  );
});
