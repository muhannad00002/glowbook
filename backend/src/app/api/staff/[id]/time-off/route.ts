import { z } from "zod";
import { db } from "@/lib/db";
import { conflict, forbidden, ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { staffDetail } from "@/server/staff";
import { audit } from "@/server/audit";

export const GET = route(async (req, { id }) => {
  const ctx = await requireSalon(req);
  if (ctx.role === "STAFF" && ctx.staffId !== id) throw forbidden();
  await staffDetail(ctx.salonId, id);
  return db.staffTimeOff.findMany({
    where: { staffId: id, salonId: ctx.salonId, endTime: { gte: new Date(Date.now() - 30 * 86400_000) } },
    orderBy: { startTime: "asc" },
  });
});

const schema = z
  .object({
    startTime: z.coerce.date(),
    endTime: z.coerce.date(),
    type: z.enum(["VACATION", "SICK", "DAY_OFF", "OTHER"]).default("VACATION"),
    reason: z.string().trim().max(200).nullable().optional(),
    /** Allow creating leave even though bookings fall inside it (they stay; front desk reassigns). */
    force: z.boolean().default(false),
  })
  .refine((v) => v.endTime > v.startTime, { message: "Leave must end after it starts." });

export const POST = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  await staffDetail(ctx.salonId, id);
  const body = await parseBody(req, schema);

  const clashes = await db.booking.findMany({
    where: {
      staffId: id,
      status: { in: ["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE"] },
      startTime: { lt: body.endTime },
      blockedUntil: { gt: body.startTime },
    },
    select: { id: true, reference: true, startTime: true, customer: { select: { name: true } } },
    orderBy: { startTime: "asc" },
  });
  if (clashes.length > 0 && !body.force) {
    throw conflict(`${clashes.length} booking(s) fall inside this leave. Reassign them first, or save anyway.`, { clashes });
  }

  const row = await db.staffTimeOff.create({
    data: { salonId: ctx.salonId, staffId: id, startTime: body.startTime, endTime: body.endTime, type: body.type, reason: body.reason ?? null },
  });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "staff.timeoff.created", entityType: "StaffTimeOff", entityId: row.id });
  return ok({ ...row, clashes }, "Time off saved.", 201);
});
