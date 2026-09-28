import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, forbidden, notFound, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { audit } from "@/server/audit";

const schema = z.object({
  role: z.enum(["MANAGER", "RECEPTIONIST", "STAFF"]).optional(),
  isActive: z.boolean().optional(),
});

async function load(salonId: string, id: string) {
  const m = await db.salonMember.findFirst({ where: { id, salonId } });
  if (!m) throw notFound("Team member not found.");
  if (m.role === "OWNER") throw forbidden("The owner can't be changed here.");
  return m;
}

export const PATCH = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, schema);
  const m = await load(ctx.salonId, id);
  if (m.userId === ctx.user.id) throw badRequest("You can't change your own access.");
  if ((m.role === "MANAGER" || body.role === "MANAGER") && ctx.role !== "OWNER") throw forbidden("Only the owner can manage managers.");
  const updated = await db.salonMember.update({ where: { id }, data: body });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "member.updated", entityType: "SalonMember", entityId: id, metadata: body });
  return updated;
});

export const DELETE = route(async (req, { id }) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const m = await load(ctx.salonId, id);
  if (m.userId === ctx.user.id) throw badRequest("You can't remove yourself.");
  if (m.role === "MANAGER" && ctx.role !== "OWNER") throw forbidden("Only the owner can remove managers.");
  await db.salonMember.delete({ where: { id } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "member.removed", entityType: "SalonMember", entityId: id });
  return { removed: true };
});
