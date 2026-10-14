import { z } from "zod";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { afterResponse } from "@/server/booking/access";
import { setTokenStatus } from "@/server/seasonal/engine";
import { notifyTokenEvent } from "@/server/notifications/service";
import { audit } from "@/server/audit";

const schema = z.object({
  status: z.enum(["CONFIRMED", "ARRIVED", "COMPLETED", "NO_SHOW", "CANCELLED"]),
  reason: z.string().trim().max(300).nullable().optional(),
  notifyCustomer: z.boolean().default(true),
});

/** Front desk: arrived → completed, no-show, or cancel (refunds are settled at the desk). */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const body = await parseBody(req, schema);
  const { previous, token } = await setTokenStatus({ salonId: ctx.salonId, tokenId: id, status: body.status, reason: body.reason });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.token.status", entityType: "SeasonalToken", entityId: id, metadata: { from: previous, to: body.status } });
  if (body.status === "CANCELLED" && body.notifyCustomer && previous !== "PENDING_PAYMENT") {
    afterResponse(() => notifyTokenEvent(id, "TOKEN_CANCELLED"));
  }
  return ok(token, null);
});
