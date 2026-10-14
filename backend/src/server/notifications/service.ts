import { db } from "@/lib/db";
import { formatLocal } from "@/lib/time";
import { randomToken, signBookingToken } from "@/lib/auth/tokens";
import type { Notification, Prisma } from "@/generated/prisma/client";
import type { NotificationChannel, NotificationType } from "@/generated/prisma/enums";
import { providers } from "./providers";
import { DEFAULT_TEMPLATES, renderTemplate } from "./templates";

/**
 * NotificationService
 *   ├── PushNotificationService   (FCM)
 *   ├── WhatsAppService           (Meta Cloud API)
 *   ├── EmailService              (Resend)
 *   └── SmsService                (Twilio)
 *
 * Flow: an event creates one Notification row per (recipient, channel) with a unique
 * `dedupeKey`, then the rows are delivered. Because the key is unique, re-running the
 * reminder cron — or two cron invocations overlapping — can never send twice.
 */

const MAX_ATTEMPTS = 3;
type Locale = "en" | "ar";

async function loadTemplate(
  salonId: string | null,
  type: NotificationType,
  channel: NotificationChannel,
  locale: Locale,
): Promise<{ title: string; body: string; whatsappTemplateName: string | null }> {
  const rows = await db.notificationTemplate.findMany({
    where: {
      type,
      channel,
      locale,
      isActive: true,
      OR: [{ salonId: null }, ...(salonId ? [{ salonId }] : [])],
    },
  });
  const row = rows.find((r) => r.salonId === salonId) ?? rows.find((r) => r.salonId === null);
  const fallback = DEFAULT_TEMPLATES[type][locale];
  return {
    title: row?.subject ?? fallback.title,
    body: row?.body ?? fallback.body,
    whatsappTemplateName: row?.whatsappTemplateName ?? null,
  };
}

/**
 * The customer's personal link to view, cancel or reschedule — no account needed. It
 * opens the booking page of the web app (APP_BASE_URL); the signed token covers every
 * booking of a multi-service visit.
 */
export async function manageLink(bookingId: string) {
  const base = (process.env.APP_BASE_URL ?? "http://localhost:8080").replace(/\/$/, "");
  return `${base}/booking/${bookingId}?token=${await signBookingToken(bookingId)}`;
}

// ---------------------------------------------------------------------------
// Booking events
// ---------------------------------------------------------------------------

export type BookingEventOptions = {
  /** Distinguishes repeatable events (each reschedule, each reminder window). */
  eventKey?: string;
  /** Also drop an in-app note into the salon team's inbox. */
  notifySalon?: boolean;
  /** Don't notify the person who caused the event. */
  actorUserId?: string | null;
};

export async function notifyBookingEvent(
  bookingId: string,
  type: NotificationType,
  opts: BookingEventOptions = {},
): Promise<string[]> {
  const b = await db.booking.findUnique({
    where: { id: bookingId },
    include: {
      salon: true,
      service: { select: { name: true, nameAr: true } },
      staff: { select: { name: true, nameAr: true, userId: true } },
      customer: { include: { user: { select: { id: true, locale: true, isActive: true } } } },
    },
  });
  if (!b) return [];
  // A multi-service visit speaks with one voice — its first booking — so the customer
  // gets one message for the whole visit, not one per service.
  if (b.groupId && b.groupId !== b.id) return [];
  const visit = b.groupId
    ? await db.booking.findMany({
        where: { groupId: b.groupId },
        orderBy: { startTime: "asc" },
        include: { service: { select: { name: true, nameAr: true } } },
      })
    : [b];
  const { salon, customer } = b;
  const locale: Locale = customer.user?.locale === "ar" ? "ar" : "en";
  const ar = locale === "ar";
  const serviceNames = visit.map((v) => (ar && v.service.nameAr) || v.service.name).join(ar ? " و " : " + ");
  const vars: Record<string, string> = {
    customer_name: customer.name.split(" ")[0],
    salon_name: (ar && salon.nameAr) || salon.name,
    service_name: serviceNames,
    staff_name: (ar && b.staff.nameAr) || b.staff.name,
    date: formatLocal(b.startTime, salon.timezone, locale, { weekday: "short", day: "numeric", month: "short" }),
    time: formatLocal(b.startTime, salon.timezone, locale, { hour: "numeric", minute: "2-digit" }),
    end_time: formatLocal(visit[visit.length - 1].endTime, salon.timezone, locale, { hour: "numeric", minute: "2-digit" }),
    booking_id: b.reference,
    booking_uuid: b.id,
    manage_link: await manageLink(b.id),
  };
  const keyBase = `${b.id}:${type}${opts.eventKey ? `:${opts.eventKey}` : ""}`;

  // Which channels are on for this salon, and reachable for this customer?
  const wanted: { channel: NotificationChannel; recipient: string | null; userId: string | null }[] = [];
  // The customer always hears about their own booking — even changes they made
  // themselves, since the message doubles as a receipt.
  const customerUserId = customer.user?.isActive ? customer.user.id : null;
  if (salon.notifyInApp && customerUserId) wanted.push({ channel: "IN_APP", recipient: null, userId: customerUserId });
  if (salon.notifyPush && customerUserId) wanted.push({ channel: "PUSH", recipient: customerUserId, userId: customerUserId });
  if (salon.notifyWhatsapp && customer.phone) wanted.push({ channel: "WHATSAPP", recipient: customer.phone, userId: null });
  if (salon.notifyEmail && customer.email) wanted.push({ channel: "EMAIL", recipient: customer.email, userId: null });
  if (salon.notifySms && customer.phone) wanted.push({ channel: "SMS", recipient: customer.phone, userId: null });

  const rows: Prisma.NotificationCreateManyInput[] = [];
  for (const w of wanted) {
    const tpl = await loadTemplate(salon.id, type, w.channel, locale);
    rows.push({
      salonId: salon.id,
      bookingId: b.id,
      customerId: customer.id,
      userId: w.userId,
      type,
      channel: w.channel,
      recipient: w.recipient,
      title: renderTemplate(tpl.title, vars),
      body: renderTemplate(tpl.body, vars),
      payload: { variables: vars, locale, whatsappTemplateName: tpl.whatsappTemplateName },
      dedupeKey: `${keyBase}:${w.channel}`,
    });
  }

  // Salon inbox: owners, managers, reception, and the assigned artist.
  if (opts.notifySalon) {
    const members = await db.salonMember.findMany({
      where: { salonId: salon.id, isActive: true, role: { in: ["OWNER", "MANAGER", "RECEPTIONIST"] } },
      select: { userId: true },
    });
    const teamIds = new Set(members.map((m) => m.userId));
    if (b.staff.userId) teamIds.add(b.staff.userId);
    if (opts.actorUserId) teamIds.delete(opts.actorUserId);
    const titles: Partial<Record<NotificationType, string>> = {
      BOOKING_CREATED: "New booking",
      BOOKING_CONFIRMED: "Booking confirmed",
      BOOKING_RESCHEDULED: "Booking rescheduled",
      BOOKING_CANCELLED: "Booking cancelled",
    };
    const when = formatLocal(b.startTime, salon.timezone, "en", {
      weekday: "short",
      day: "numeric",
      month: "short",
      hour: "numeric",
      minute: "2-digit",
    });
    for (const userId of teamIds) {
      rows.push({
        salonId: salon.id,
        bookingId: b.id,
        userId,
        type,
        channel: "IN_APP",
        title: `${titles[type] ?? "Booking update"} · ${customer.name}`,
        body: `${visit.map((v) => v.service.name).join(" + ")} · ${when} with ${b.staff.name}`,
        dedupeKey: `${keyBase}:team:${userId}`,
      });
    }
  }

  if (rows.length === 0) return [];
  await db.notification.createMany({ data: rows, skipDuplicates: true });
  const created = await db.notification.findMany({
    where: { dedupeKey: { in: rows.map((r) => r.dedupeKey) }, status: "PENDING", attempts: 0 },
    select: { id: true },
  });
  const ids = created.map((c) => c.id);
  await deliverMany(ids);
  return ids;
}

// ---------------------------------------------------------------------------
// Transactional (account) messages — not gated by salon channel toggles
// ---------------------------------------------------------------------------

export async function sendAccountMessage(input: {
  type: "PASSWORD_RESET" | "PHONE_OTP";
  channel: "EMAIL" | "SMS" | "WHATSAPP";
  to: string;
  locale?: string;
  userId?: string | null;
  variables: Record<string, string>;
}) {
  const locale: Locale = input.locale === "ar" ? "ar" : "en";
  const tpl = await loadTemplate(null, input.type, input.channel, locale);
  const n = await db.notification.create({
    data: {
      type: input.type,
      channel: input.channel,
      recipient: input.to,
      userId: input.userId ?? null,
      title: renderTemplate(tpl.title, input.variables),
      body: renderTemplate(tpl.body, input.variables),
      // Secrets (codes, reset links) are not persisted in the payload.
      payload: { locale },
      dedupeKey: `${input.type}:${randomToken(12)}`,
    },
  });
  await deliver(n);
  return n.id;
}

// ---------------------------------------------------------------------------
// Delivery
// ---------------------------------------------------------------------------

type Payload = { variables?: Record<string, string>; locale?: string; whatsappTemplateName?: string | null };

export async function deliverMany(ids: string[]) {
  if (ids.length === 0) return;
  const rows = await db.notification.findMany({ where: { id: { in: ids } } });
  // Small fan-out; sequential keeps provider rate limits happy.
  for (const n of rows) await deliver(n);
}

export async function deliver(n: Notification): Promise<void> {
  // Claim the row so overlapping cron runs can't both send it.
  const claimed = await db.notification.updateMany({
    where: { id: n.id, status: { in: ["PENDING", "FAILED"] }, attempts: n.attempts },
    data: { attempts: { increment: 1 } },
  });
  if (claimed.count !== 1) return;

  const finish = (data: Prisma.NotificationUpdateInput) => db.notification.update({ where: { id: n.id }, data });

  if (n.channel === "IN_APP") {
    await finish({ status: "SENT", sentAt: new Date() });
    return;
  }

  const provider = providers[n.channel];
  if (!provider.isConfigured()) {
    if (process.env.NODE_ENV !== "production") {
      console.info(`[notify:${n.channel.toLowerCase()} — not configured, logged only] → ${n.recipient}: ${n.body}`);
    }
    await finish({ status: "SKIPPED", lastError: `${provider.name} is not configured` });
    return;
  }

  const payload = (n.payload ?? {}) as Payload;
  const base = {
    title: n.title,
    body: n.body,
    type: n.type,
    locale: payload.locale ?? "en",
    variables: payload.variables ?? {},
    whatsappTemplateName: payload.whatsappTemplateName,
  };

  try {
    if (n.channel === "PUSH") {
      const devices = n.userId ? await db.deviceToken.findMany({ where: { userId: n.userId } }) : [];
      if (devices.length === 0) {
        await finish({ status: "SKIPPED", lastError: "No registered devices" });
        return;
      }
      let delivered = 0;
      let lastId: string | undefined;
      for (const d of devices) {
        const r = await provider.send({ ...base, to: d.token });
        if (r.invalidRecipient) await db.deviceToken.delete({ where: { id: d.id } }).catch(() => {});
        else {
          delivered++;
          lastId = r.providerMessageId;
        }
      }
      await finish(
        delivered > 0
          ? { status: "SENT", sentAt: new Date(), providerMessageId: lastId }
          : { status: "SKIPPED", lastError: "All device tokens were invalid" },
      );
      return;
    }

    if (!n.recipient) {
      await finish({ status: "SKIPPED", lastError: "No recipient" });
      return;
    }
    const r = await provider.send({ ...base, to: n.recipient });
    await finish({ status: "SENT", sentAt: new Date(), providerMessageId: r.providerMessageId ?? null });
  } catch (e) {
    await finish({ status: "FAILED", lastError: String((e as Error).message ?? e).slice(0, 500) });
  }
}

/** Retries FAILED rows from the last day (bounded by MAX_ATTEMPTS). Used by the cron. */
export async function retryFailed(limit = 50): Promise<number> {
  const rows = await db.notification.findMany({
    where: {
      status: { in: ["FAILED", "PENDING"] },
      attempts: { lt: MAX_ATTEMPTS },
      createdAt: { gte: new Date(Date.now() - 86400_000), lte: new Date(Date.now() - 60_000) },
    },
    take: limit,
    orderBy: { createdAt: "asc" },
  });
  for (const n of rows) await deliver(n);
  return rows.length;
}
