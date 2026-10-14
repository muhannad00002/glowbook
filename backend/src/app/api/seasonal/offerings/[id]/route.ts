import { db } from "@/lib/db";
import { conflict, ok, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { checkOffering, offeringInput, ownedOffering } from "@/server/seasonal/admin";
import { prepayFor } from "@/server/seasonal/engine";
import { audit } from "@/server/audit";

/**
 * Edits apply to tokens taken from now on. Tokens already issued keep the time, price
 * and advance they were sold with.
 */
export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const current = await ownedOffering(ctx.salonId, id);
  const patch = await parsePatch(req, offeringInput);
  const merged = { ...current, ...patch };
  checkOffering(merged);
  if (patch.tokenMinutes !== undefined && patch.tokenMinutes !== current.tokenMinutes) {
    const live = await db.seasonalToken.count({
      where: { offeringId: id, status: { in: ["PENDING_PAYMENT", "CONFIRMED", "ARRIVED"] }, startTime: { gt: new Date() } },
    });
    if (live > 0) throw conflict("Customers already hold upcoming tokens, so the token length can't change. Add a new offering instead.");
  }
  const o = await db.seasonalOffering.update({
    where: { id },
    data: { ...patch, ...(merged.prepayMode === "FULL" ? { prepayBaisa: 0 } : {}) },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.offering.updated", entityType: "SeasonalOffering", entityId: id });
  return ok({ ...o, effectivePrepayBaisa: prepayFor(o) }, "Offering saved");
});

export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await ownedOffering(ctx.salonId, id);
  const used = await db.seasonalToken.count({ where: { offeringId: id } });
  if (used > 0) throw conflict("Customers have tokens for this offering. Turn it off instead of deleting it.");
  await db.seasonalOffering.delete({ where: { id } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.offering.deleted", entityType: "SeasonalOffering", entityId: id });
  return ok(null, "Offering deleted");
});
