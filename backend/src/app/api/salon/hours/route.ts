import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { audit } from "@/server/audit";

export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  return db.salonWorkingHour.findMany({ where: { salonId: ctx.salonId }, orderBy: { dayOfWeek: "asc" } });
});

const schema = z.object({
  // One entry per open day; days not listed are closed.
  days: z
    .array(
      z.object({
        dayOfWeek: z.number().int().min(0).max(6),
        openMinute: z.number().int().min(0).max(1439),
        closeMinute: z.number().int().min(1).max(1440),
      }),
    )
    .max(7),
});

/** Replaces the weekly schedule. */
export const PUT = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const { days } = await parseBody(req, schema);
  const seen = new Set<number>();
  for (const d of days) {
    if (d.closeMinute <= d.openMinute) throw badRequest("Closing time must be after opening time.");
    if (seen.has(d.dayOfWeek)) throw badRequest("Each day can only appear once.");
    seen.add(d.dayOfWeek);
  }
  await db.$transaction([
    db.salonWorkingHour.deleteMany({ where: { salonId: ctx.salonId } }),
    db.salonWorkingHour.createMany({ data: days.map((d) => ({ ...d, salonId: ctx.salonId })) }),
  ]);
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "salon.hours.updated", entityType: "Salon", entityId: ctx.salonId });
  return db.salonWorkingHour.findMany({ where: { salonId: ctx.salonId }, orderBy: { dayOfWeek: "asc" } });
});
