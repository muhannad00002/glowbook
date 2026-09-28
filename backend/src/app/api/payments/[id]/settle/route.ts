import { z } from "zod";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { settleRefund } from "@/server/payments/service";
import { audit } from "@/server/audit";

const schema = z.object({ method: z.enum(["CASH", "CARD", "BANK_TRANSFER", "ONLINE"]) });

/** Marks an owed refund as paid back to the client. */
export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const { method } = await parseBody(req, schema);
  const payment = await settleRefund({ salonId: ctx.salonId, paymentId: id, method, userId: ctx.user.id });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "refund.settled", entityType: "Payment", entityId: id });
  return ok(payment, "Refund recorded.");
});
