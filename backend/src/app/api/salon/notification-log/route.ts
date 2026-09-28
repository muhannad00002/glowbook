import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { providers } from "@/server/notifications/providers";

const schema = z.object({
  channel: z.enum(["PUSH", "WHATSAPP", "EMAIL", "SMS"]).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

/** Outbound delivery log (customer-facing channels) + which providers are configured. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const q = parseQuery(req, schema);
  const items = await db.notification.findMany({
    where: {
      salonId: ctx.salonId,
      channel: q.channel ? q.channel : { not: "IN_APP" },
    },
    select: {
      id: true,
      type: true,
      channel: true,
      status: true,
      recipient: true,
      title: true,
      body: true,
      attempts: true,
      lastError: true,
      sentAt: true,
      createdAt: true,
      booking: { select: { id: true, reference: true } },
    },
    orderBy: { createdAt: "desc" },
    take: q.limit,
  });
  return {
    items,
    providers: Object.fromEntries(Object.entries(providers).map(([k, p]) => [k, { name: p.name, configured: p.isConfigured() }])),
  };
});
