import { z } from "zod";
import { db } from "@/lib/db";
import { conflict, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { audit } from "@/server/audit";

/** The caller's current salon, with every setting (team view). */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const salon = await db.salon.findUniqueOrThrow({
    where: { id: ctx.salonId },
    include: { workingHours: { orderBy: { dayOfWeek: "asc" } } },
  });
  return { ...salon, myRole: ctx.role, myStaffId: ctx.staffId };
});

const optionalText = (max: number) => z.string().trim().max(max).nullable().optional();

const patchSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  nameAr: optionalText(80),
  slug: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Use lowercase letters, numbers and dashes.")
    .min(3)
    .max(48)
    .optional(),
  tagline: optionalText(120),
  taglineAr: optionalText(120),
  description: optionalText(2000),
  descriptionAr: optionalText(2000),
  category: z.enum(["MAKEUP", "BEAUTY", "HAIR", "STUDIO", "ARTIST"]).optional(),
  phone: optionalText(20),
  whatsapp: optionalText(20),
  email: z.string().email().nullable().optional(),
  address: optionalText(200),
  addressAr: optionalText(200),
  city: optionalText(60),
  latitude: z.number().min(-90).max(90).nullable().optional(),
  longitude: z.number().min(-180).max(180).nullable().optional(),
  timezone: z.string().max(60).optional(),
  logoUrl: z.string().url().nullable().optional(),
  coverUrl: z.string().url().nullable().optional(),
  photos: z.array(z.string().url()).max(12).optional(),
  isPublished: z.boolean().optional(),
  slotIntervalMinutes: z.union([z.literal(5), z.literal(10), z.literal(15), z.literal(20), z.literal(30), z.literal(60)]).optional(),
  minNoticeMinutes: z.number().int().min(0).max(7 * 24 * 60).optional(),
  bookingHorizonDays: z.number().int().min(1).max(365).optional(),
  autoConfirm: z.boolean().optional(),
  cancellationWindowHours: z.number().int().min(0).max(14 * 24).optional(),
  lateCancellationFeeBaisa: z.number().int().min(0).max(10_000_000).optional(),
  depositPolicy: z.enum(["REFUNDABLE_IN_WINDOW", "NON_REFUNDABLE"]).optional(),
  allowCustomerReschedule: z.boolean().optional(),
  notifyInApp: z.boolean().optional(),
  notifyPush: z.boolean().optional(),
  notifyWhatsapp: z.boolean().optional(),
  notifyEmail: z.boolean().optional(),
  notifySms: z.boolean().optional(),
  remind24h: z.boolean().optional(),
  remind3h: z.boolean().optional(),
  reviewRequests: z.boolean().optional(),
});

export const PATCH = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, patchSchema);
  if (body.timezone) {
    try {
      new Intl.DateTimeFormat("en", { timeZone: body.timezone });
    } catch {
      throw conflict("Unknown timezone.");
    }
  }
  if (body.slug) {
    const taken = await db.salon.findFirst({ where: { slug: body.slug, id: { not: ctx.salonId } }, select: { id: true } });
    if (taken) throw conflict("That booking link is already taken.");
  }
  const salon = await db.salon.update({ where: { id: ctx.salonId }, data: body });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "salon.updated", entityType: "Salon", entityId: ctx.salonId, metadata: { fields: Object.keys(body) } });
  return salon;
});
