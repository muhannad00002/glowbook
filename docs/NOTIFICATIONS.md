# Notifications & reminders

```
Booking event (API route)            Vercel Cron (every 15 min)
        │                                      │
        ▼                                      ▼
notifyBookingEvent()                   runScheduledJobs()
        │                        24h / 3h reminders · review requests
        │                        unpaid-deposit expiry · retry failed
        ▼                                      │
 Notification rows (one per recipient × channel, unique dedupeKey) ◄┘
        │
        ▼  deliver()  — claims the row, then sends
 ┌──────────────┬───────────────┬──────────────┬────────────┬──────────┐
 IN_APP          PUSH (FCM v1)   WHATSAPP (Meta) EMAIL (Resend) SMS (Twilio)
```

Code: `backend/src/server/notifications/` — `service.ts` (NotificationService),
`providers.ts` (PushNotificationService, WhatsAppService, EmailService, SmsService),
`templates.ts` (default copy, EN + AR).

## Never twice

Every row has a unique `dedupeKey`, e.g. `bookingId:REMINDER_24H:<startTime ISO>:WHATSAPP`.
Creating rows uses `skipDuplicates`, so re-running the cron (or two overlapping runs) is a no-op.
Including the start time means a **rescheduled** booking gets fresh reminders for its new time.
Delivery first "claims" a row (`attempts` compare-and-swap) so two workers can't both send it.

## Channels are honest

A provider with no credentials marks its rows `SKIPPED — <provider> is not configured`
(visible in Settings → Delivery log). Nothing pretends to have been sent.

| Channel | Env vars | Notes |
|---|---|---|
| Push | `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` | Service-account JWT → OAuth → `messages:send`. Invalid tokens are deleted. App registers tokens at `POST /api/me/devices`. |
| WhatsApp | `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID` | Meta Cloud API, template messages. |
| Email | `RESEND_API_KEY`, `EMAIL_FROM` | Also used for password reset. |
| SMS | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` | Also used for phone OTP. |

Salon admins toggle each channel (and the 24h / 3h reminders and review requests) in Settings.

## WhatsApp templates to register (Meta Business Manager)

Register each in English (`en`) and Arabic (`ar`). Body parameters, in order:

| Template | Parameters |
|---|---|
| `booking_confirmation` | customer_name, salon_name, service_name, date, time, staff_name, booking_id |
| `booking_reminder_24h` | customer_name, salon_name, service_name, date, time, staff_name |
| `booking_reminder_3h` | customer_name, salon_name, service_name, time, staff_name |
| `booking_cancelled` | customer_name, salon_name, service_name, date, time, booking_id |
| `booking_rescheduled` | customer_name, salon_name, service_name, date, time, booking_id |
| `booking_completed` | customer_name, salon_name, service_name |

Example body (`booking_confirmation`, en):
`Hi {{1}} 💕 Your appointment at {{2}} is confirmed: {{3}} on {{4}} at {{5}} with {{6}}. Ref {{7}}.`

The mapping lives in `WHATSAPP_TEMPLATE_PARAMS` / `WHATSAPP_TEMPLATE_NAMES`; a salon can point a
type at a different approved template via `NotificationTemplate.whatsappTemplateName`.

## Scheduling on Vercel

`vercel.json` schedules `GET /api/cron/reminders` every 15 minutes; Vercel sends
`Authorization: Bearer $CRON_SECRET` automatically. **Vercel Hobby only allows daily crons** —
on Hobby, use `.github/workflows/reminders.yml` (set repo secrets `API_BASE_URL`, `CRON_SECRET`)
or any external scheduler calling the same URL with the same header.
