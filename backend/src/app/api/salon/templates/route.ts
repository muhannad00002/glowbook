import { z } from "zod";
import { db } from "@/lib/db";
import { parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { DEFAULT_TEMPLATES } from "@/server/notifications/templates";

const TYPES = ["BOOKING_CREATED", "BOOKING_CONFIRMED", "BOOKING_RESCHEDULED", "BOOKING_CANCELLED", "REMINDER_24H", "REMINDER_3H", "BOOKING_COMPLETED", "REVIEW_REQUEST"] as const;
const CHANNELS = ["IN_APP", "PUSH", "WHATSAPP", "EMAIL", "SMS"] as const;

/** Effective templates for this salon (its overrides on top of the platform defaults). */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const rows = await db.notificationTemplate.findMany({
    where: { OR: [{ salonId: null }, { salonId: ctx.salonId }], type: { in: [...TYPES] } },
  });
  const out = [];
  for (const type of TYPES) {
    for (const locale of ["en", "ar"] as const) {
      for (const channel of CHANNELS) {
        const own = rows.find((r) => r.salonId === ctx.salonId && r.type === type && r.locale === locale && r.channel === channel);
        const def = rows.find((r) => r.salonId === null && r.type === type && r.locale === locale && r.channel === channel);
        const fb = DEFAULT_TEMPLATES[type][locale];
        out.push({
          type,
          channel,
          locale,
          subject: own?.subject ?? def?.subject ?? fb.title,
          body: own?.body ?? def?.body ?? fb.body,
          isCustom: !!own,
        });
      }
    }
  }
  return out;
});

const schema = z.object({
  type: z.enum(TYPES),
  channel: z.enum(CHANNELS),
  locale: z.enum(["en", "ar"]),
  subject: z.string().trim().max(120).nullable().optional(),
  /** Empty body = remove the override and fall back to the platform default. */
  body: z.string().trim().max(1000),
});

export const PUT = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const b = await parseBody(req, schema);
  const key = { salonId: ctx.salonId, type: b.type, channel: b.channel, locale: b.locale };
  if (!b.body) {
    await db.notificationTemplate.deleteMany({ where: key });
    return { reset: true };
  }
  return db.notificationTemplate.upsert({
    where: { salonId_type_channel_locale: key },
    create: { ...key, subject: b.subject ?? null, body: b.body },
    update: { subject: b.subject ?? null, body: b.body },
  });
});
