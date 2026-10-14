import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { checkOffering, offeringInput, ownedEvent } from "@/server/seasonal/admin";
import { prepayFor } from "@/server/seasonal/engine";
import { audit } from "@/server/audit";

export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await ownedEvent(ctx.salonId, id);
  const body = await parseBody(req, offeringInput);
  checkOffering(body);
  const o = await db.seasonalOffering.create({
    data: { ...body, prepayBaisa: body.prepayMode === "FIXED" ? body.prepayBaisa : 0, eventId: id, salonId: ctx.salonId },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.offering.created", entityType: "SeasonalOffering", entityId: o.id });
  return ok({ ...o, effectivePrepayBaisa: prepayFor(o), tokenCount: 0 }, "Offering added ✨", 201);
});
