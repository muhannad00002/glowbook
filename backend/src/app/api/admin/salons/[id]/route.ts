import { z } from "zod";
import { db } from "@/lib/db";
import { notFound, parsePatch, route } from "@/lib/http";
import { requireSuperAdmin } from "@/lib/auth/context";
import { audit } from "@/server/audit";

const schema = z.object({
  isPublished: z.boolean(),
  plan: z.enum(["FREE", "STARTER", "PRO"]),
  subscriptionStatus: z.enum(["TRIALING", "ACTIVE", "PAST_DUE", "CANCELLED"]),
  trialEndsAt: z.coerce.date().nullable(),
});

export const PATCH = route(async (req, { id }) => {
  const admin = await requireSuperAdmin(req);
  const body = await parsePatch(req, schema);
  const exists = await db.salon.findUnique({ where: { id }, select: { id: true } });
  if (!exists) throw notFound("Salon not found.");
  const salon = await db.salon.update({ where: { id }, data: body });
  await audit({ req, salonId: id, userId: admin.id, action: "admin.salon.updated", entityType: "Salon", entityId: id, metadata: { fields: Object.keys(body) } });
  return salon;
});
