import { db } from "@/lib/db";
import { conflict, ok, parsePatch, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { dateColumnToString } from "@/lib/time";
import { checkEvent, eventInput, eventView, ownedEvent, toDates } from "@/server/seasonal/admin";
import { audit } from "@/server/audit";

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const current = await ownedEvent(ctx.salonId, id);
  const patch = await parsePatch(req, eventInput);
  checkEvent({
    startDate: patch.startDate ?? dateColumnToString(current.startDate),
    endDate: patch.endDate ?? dateColumnToString(current.endDate),
    openMinute: patch.openMinute ?? current.openMinute,
    closeMinute: patch.closeMinute ?? current.closeMinute,
  });
  const event = await db.seasonalEvent.update({ where: { id }, data: { ...patch, ...toDates(patch) } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.event.updated", entityType: "SeasonalEvent", entityId: id });
  return ok(eventView(event), "Event saved");
});

/** Deleting is only for events nobody has taken a token for; otherwise switch it off. */
export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await ownedEvent(ctx.salonId, id);
  const used = await db.seasonalToken.count({ where: { offering: { eventId: id } } });
  if (used > 0) throw conflict("Customers have tokens for this event. Turn it off instead of deleting it.");
  await db.seasonalEvent.delete({ where: { id } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.event.deleted", entityType: "SeasonalEvent", entityId: id });
  return ok(null, "Event deleted");
});
