import { SignJWT, importPKCS8 } from "jose";
import type { NotificationChannel, NotificationType } from "@/generated/prisma/enums";

/**
 * Channel providers. Each one is inert until its credentials exist in the environment
 * (Vercel env vars — never the app). An unconfigured channel is recorded as SKIPPED
 * with a reason, so the delivery log is honest about what actually went out.
 */

export type OutboundMessage = {
  to: string;
  title: string;
  body: string;
  type: NotificationType;
  locale: string;
  /** Template variables, e.g. customer_name → "Sarah". */
  variables: Record<string, string>;
  whatsappTemplateName?: string | null;
};

export type SendResult = { providerMessageId?: string; invalidRecipient?: boolean };

export interface ChannelProvider {
  channel: NotificationChannel;
  name: string;
  isConfigured(): boolean;
  send(msg: OutboundMessage): Promise<SendResult>;
}

const env = (k: string) => process.env[k]?.trim() || undefined;

async function expectOk(res: Response, what: string) {
  if (res.ok) return res;
  const text = await res.text().catch(() => "");
  throw new Error(`${what} failed (${res.status}): ${text.slice(0, 300)}`);
}

// ---------------------------------------------------------------------------
// WhatsApp — Meta WhatsApp Business Cloud API
// ---------------------------------------------------------------------------

/**
 * Order of {{n}} parameters in the approved WhatsApp templates. Keep this in sync with
 * the templates registered in Meta Business Manager (see docs/NOTIFICATIONS.md).
 */
export const WHATSAPP_TEMPLATE_PARAMS: Partial<Record<NotificationType, string[]>> = {
  BOOKING_CREATED: ["customer_name", "salon_name", "service_name", "date", "time", "booking_id", "manage_link"],
  BOOKING_CONFIRMED: ["customer_name", "salon_name", "service_name", "date", "time", "staff_name", "booking_id", "manage_link"],
  BOOKING_RESCHEDULED: ["customer_name", "salon_name", "service_name", "date", "time", "booking_id", "manage_link"],
  BOOKING_CANCELLED: ["customer_name", "salon_name", "service_name", "date", "time", "booking_id"],
  REMINDER_24H: ["customer_name", "salon_name", "service_name", "date", "time", "staff_name", "manage_link"],
  REMINDER_3H: ["customer_name", "salon_name", "service_name", "time", "staff_name"],
  BOOKING_COMPLETED: ["customer_name", "salon_name", "service_name"],
  REVIEW_REQUEST: ["customer_name", "salon_name"],
};

export const WHATSAPP_TEMPLATE_NAMES: Partial<Record<NotificationType, string>> = {
  BOOKING_CREATED: "booking_confirmation",
  BOOKING_CONFIRMED: "booking_confirmation",
  BOOKING_RESCHEDULED: "booking_rescheduled",
  BOOKING_CANCELLED: "booking_cancelled",
  REMINDER_24H: "booking_reminder_24h",
  REMINDER_3H: "booking_reminder_3h",
  BOOKING_COMPLETED: "booking_completed",
  REVIEW_REQUEST: "booking_completed",
};

export class WhatsAppService implements ChannelProvider {
  channel = "WHATSAPP" as const;
  name = "whatsapp-cloud";
  isConfigured() {
    return !!(env("WHATSAPP_TOKEN") && env("WHATSAPP_PHONE_NUMBER_ID"));
  }
  async send(msg: OutboundMessage): Promise<SendResult> {
    const version = env("WHATSAPP_API_VERSION") ?? "v21.0";
    const url = `https://graph.facebook.com/${version}/${env("WHATSAPP_PHONE_NUMBER_ID")}/messages`;
    const templateName = msg.whatsappTemplateName ?? WHATSAPP_TEMPLATE_NAMES[msg.type];
    const to = msg.to.replace(/^\+/, "");
    const payload = templateName
      ? {
          messaging_product: "whatsapp",
          to,
          type: "template",
          template: {
            name: templateName,
            language: { code: msg.locale === "ar" ? "ar" : "en" },
            components: [
              {
                type: "body",
                parameters: (WHATSAPP_TEMPLATE_PARAMS[msg.type] ?? []).map((k) => ({
                  type: "text",
                  text: msg.variables[k] ?? "",
                })),
              },
            ],
          },
        }
      : { messaging_product: "whatsapp", to, type: "text", text: { body: msg.body } };

    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${env("WHATSAPP_TOKEN")}`, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    await expectOk(res, "WhatsApp send");
    const json = (await res.json()) as { messages?: { id: string }[] };
    return { providerMessageId: json.messages?.[0]?.id };
  }
}

// ---------------------------------------------------------------------------
// Email — Resend HTTP API
// ---------------------------------------------------------------------------

export class EmailService implements ChannelProvider {
  channel = "EMAIL" as const;
  name = "resend";
  isConfigured() {
    return !!(env("RESEND_API_KEY") && env("EMAIL_FROM"));
  }
  async send(msg: OutboundMessage): Promise<SendResult> {
    const html = `<div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#2A2330">
      <h2 style="font-family:Georgia,serif;color:#8E4B61;margin:0 0 12px">${escapeHtml(msg.title)}</h2>
      <p style="font-size:15px;line-height:1.6;white-space:pre-line">${escapeHtml(msg.body)}</p>
      <p style="font-size:12px;color:#8A7F87;margin-top:24px">Sent by Glowbook</p></div>`;
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env("RESEND_API_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: env("EMAIL_FROM"), to: [msg.to], subject: msg.title, text: msg.body, html }),
    });
    await expectOk(res, "Email send");
    const json = (await res.json()) as { id?: string };
    return { providerMessageId: json.id };
  }
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

// ---------------------------------------------------------------------------
// SMS — Twilio Messages API
// ---------------------------------------------------------------------------

export class SmsService implements ChannelProvider {
  channel = "SMS" as const;
  name = "twilio";
  isConfigured() {
    return !!(env("TWILIO_ACCOUNT_SID") && env("TWILIO_AUTH_TOKEN") && env("TWILIO_FROM"));
  }
  async send(msg: OutboundMessage): Promise<SendResult> {
    const sid = env("TWILIO_ACCOUNT_SID")!;
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${Buffer.from(`${sid}:${env("TWILIO_AUTH_TOKEN")}`).toString("base64")}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: msg.to, From: env("TWILIO_FROM")!, Body: msg.body }),
    });
    await expectOk(res, "SMS send");
    const json = (await res.json()) as { sid?: string };
    return { providerMessageId: json.sid };
  }
}

// ---------------------------------------------------------------------------
// Push — Firebase Cloud Messaging HTTP v1
// ---------------------------------------------------------------------------

let fcmToken: { value: string; expiresAt: number } | null = null;

async function fcmAccessToken(): Promise<string> {
  if (fcmToken && fcmToken.expiresAt > Date.now() + 60_000) return fcmToken.value;
  const clientEmail = env("FCM_CLIENT_EMAIL")!;
  const key = await importPKCS8(env("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n"), "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  await expectOk(res, "FCM auth");
  const json = (await res.json()) as { access_token: string; expires_in: number };
  fcmToken = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return fcmToken.value;
}

export class PushNotificationService implements ChannelProvider {
  channel = "PUSH" as const;
  name = "fcm";
  isConfigured() {
    return !!(env("FCM_PROJECT_ID") && env("FCM_CLIENT_EMAIL") && env("FCM_PRIVATE_KEY"));
  }
  /** `msg.to` is a single device token; the dispatcher fans out per device. */
  async send(msg: OutboundMessage): Promise<SendResult> {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${env("FCM_PROJECT_ID")}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${await fcmAccessToken()}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token: msg.to,
          notification: { title: msg.title, body: msg.body },
          data: { type: msg.type, bookingId: msg.variables.booking_uuid ?? "" },
        },
      }),
    });
    if (res.status === 404 || res.status === 400) {
      const text = await res.text();
      if (text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) return { invalidRecipient: true };
      throw new Error(`FCM send failed (${res.status}): ${text.slice(0, 300)}`);
    }
    await expectOk(res, "FCM send");
    const json = (await res.json()) as { name?: string };
    return { providerMessageId: json.name };
  }
}

export const providers: Record<Exclude<NotificationChannel, "IN_APP">, ChannelProvider> = {
  PUSH: new PushNotificationService(),
  WHATSAPP: new WhatsAppService(),
  EMAIL: new EmailService(),
  SMS: new SmsService(),
};
