import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { checkEvent, eventInput, eventView, toDates } from "@/server/seasonal/admin";
import { prepayFor } from "@/server/seasonal/engine";
import { audit } from "@/server/audit";

/** Seasonal events with their offerings and how many tokens are live. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const events = await db.seasonalEvent.findMany({
    where: { salonId: ctx.salonId },
    include: {
      offerings: {
        orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
        include: { _count: { select: { tokens: { where: { status: { in: ["CONFIRMED", "ARRIVED", "COMPLETED"] } } } } } },
      },
    },
    orderBy: { startDate: "desc" },
  });
  return events.map((e) => ({
    ...eventView(e),
    offerings: e.offerings.map(({ _count, ...o }) => ({ ...o, effectivePrepayBaisa: prepayFor(o), tokenCount: _count.tokens })),
  }));
});

export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, eventInput);
  checkEvent(body);
  const event = await db.seasonalEvent.create({ data: { ...body, ...toDates(body), salonId: ctx.salonId } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "seasonal.event.created", entityType: "SeasonalEvent", entityId: event.id });
  return ok({ ...eventView(event), offerings: [] }, "Event created ✨", 201);
});
