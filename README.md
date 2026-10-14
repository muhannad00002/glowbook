# Glowbook

Booking & management SaaS for makeup artists, beauty salons, hair salons and studios —
multi-salon, bilingual (English / العربية), with a customer booking flow, a public booking
page per salon, and a Flutter app for owners, reception, artists and customers.

```
Flutter (Android · iOS · Web)
        │  HTTPS / REST  (bearer token; no secrets in the app)
        ▼
Next.js API routes on Vercel  (backend/)
        │  Prisma 7 + @prisma/adapter-pg
        ▼
Neon PostgreSQL
        │
        └── NotificationService ─► Push (FCM) · WhatsApp · Email · SMS
```

```
glowbook/
  backend/            Next.js 16 API (TypeScript), Prisma schema + migrations + seed
  app/                Flutter app (Riverpod, go_router, dio, Material 3)
  design-system/      Design tokens & rules (MASTER.md)
  docs/               NOTIFICATIONS.md (channels, WhatsApp templates, cron)
  .github/workflows/  reminders.yml (cron fallback for Vercel Hobby)
```

---

## Live (demo) deployment

| | URL |
|---|---|
| Web app | https://glowbook-salon-sepia.vercel.app |
| Public booking page | https://glowbook-salon-sepia.vercel.app/salon/maison-beauty |
| API | https://glowbook-api-eta.vercel.app/api/health |

Vercel team **singaf** (Hobby): projects `glowbook-api` (root `backend/`) and `glowbook-salon`
(static `app/build/web`). Neon project **glowbook** (`calm-glade-96577176`, aws-eu-central-1),
seeded with the demo data — the demo logins below work there. **Change or remove the demo
accounts before real salons use it.** Production secrets live only in Vercel env vars (a local
copy is in the git-ignored `backend/.env.production.local`).

Reminders: Hobby allows one cron per day, so `vercel.json` runs the job daily at 05:00 UTC.
For the intended 15-minute cadence, push the repo to GitHub and set the `API_BASE_URL` and
`CRON_SECRET` repository secrets for `.github/workflows/reminders.yml` (or upgrade to Pro and set
the schedule back to `*/15 * * * *`).

---

## Customer booking flow (3 steps)

1. **Choose** — toggle one or more services, pick an artist (only those who offer *all* chosen
   services) or "Any", then a date and time. Several services become one visit: consecutive
   bookings with the same artist, sharing a `groupId`, booked atomically.
2. **Details** — name and phone.
3. **Verify** — a 6-digit code to that phone, then the booking is made. The API refuses a public
   booking unless the phone is proven (a 30-minute phone token from the code step, or a signed-in
   account whose verified phone matches) — it is not just a UI step.

Without an SMS/WhatsApp provider codes can't be delivered: `OTP_TEST_MODE=true` makes the API
return the code (the app shows it as "Test mode"). Demo use only.

---

## Key technical decisions

**Double bookings are impossible at the database level.** Two independent guards:
1. Inside a transaction the engine takes a Postgres advisory lock on the artist
   (`pg_advisory_xact_lock`), then re-runs the full availability check (salon hours, staff shifts,
   holidays / special hours, leave, blocked time, existing bookings + buffer). Concurrent requests
   for the same artist serialize; the second sees the first's row.
2. An exclusion constraint (`booking_no_overlap`, btree_gist) rejects any overlapping live booking
   for the same artist even if application code were bypassed.

The API test fires 8 simultaneous bookings at one slot: exactly one succeeds, seven get
`409 "Appointment is no longer available."`

**One availability engine.** `backend/src/server/booking/availability.ts` loads a date range in a
handful of queries, then pure functions decide both *which slots to show* and *whether a booking
may be written*. Flutter never computes availability.

**Tenancy from the server, not the client.** Every salon route resolves the caller's salon from
`SalonMember` rows. A client may *request* a salon with `X-Salon-Id` (owners of several salons),
but membership is verified; spoofing returns 403. Every query is scoped by `salonId`; id lookups
use `findFirst({ id, salonId })`, so Salon B gets 404 for Salon A's records.

**Privacy by construction.** Customer-facing responses use dedicated Prisma `select`s that omit
`Booking.internalNotes` and `Customer.notes` — fields can't leak by forgetting to delete them.

**Money is integer baisa** (1 OMR = 1000). **Times are `timestamptz`**; schedules are salon-local
minutes; the app renders every time in the *salon's* timezone. The DB session is pinned to UTC so
the pg adapter's offset-less timestamps can never be read in another timezone.

**Auth:** email/password (bcrypt), phone OTP (SMS/WhatsApp), Google & Apple ID-token verification
(JWKS). 15-min HS256 access tokens + rotating refresh tokens (hashed, reuse ⇒ revoke all).
Role-based routing: Super admin → `/platform`, Owner/Manager/Reception → `/admin`,
Artist → `/staff`, Customer → `/discover`. Guests book without an account and get a signed
manage link (`/booking/:id?token=…`).

**Next.js route handlers instead of Hono** — avoids the Vercel catch-all routing issues seen with
Hono in a sibling project; each endpoint is a real file route.

---

## Local development

1. **Install Flutter** (stable, Dart ≥ 3.13) — https://docs.flutter.dev/get-started/install
2. **Install Node.js 20+** (tested on 24).
3. **Configure Neon** — create a project at https://console.neon.tech, copy the **pooled**
   connection string (host contains `-pooler`) and the **direct** one.
   *No Neon yet?* `npm run db:local` starts a real local PostgreSQL (same engine, btree_gist
   included) on `localhost:5433` — the `.env` defaults already point at it.
4. **Environment variables**
   ```bash
   cd backend
   cp .env.example .env      # fill DATABASE_URL, DIRECT_URL, AUTH_SECRET, CRON_SECRET
   ```
5. **Install dependencies**
   ```bash
   npm install               # in backend/
   ```
   ```bash
   flutter pub get           # in app/
   ```
6. **Generate the Prisma client**
   ```bash
   npm run db:generate
   ```
7. **Run migrations**
   ```bash
   npm run db:deploy         # or `npm run db:migrate` while changing the schema
   ```
8. **Seed demo data**
   ```bash
   npm run db:seed
   ```
9. **Start the API** (http://localhost:3000)
   ```bash
   npm run dev
   ```
10. **Start the Flutter app**
    ```bash
    flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
    ```
    Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:3000`.
    Or build web and serve it with deep-link fallback:
    ```bash
    flutter build web --dart-define=API_BASE_URL=http://localhost:3000
    ```
    ```bash
    node tool/serve_web.mjs 8080
    ```

### Demo accounts (seed — development only)

| Role | Email | Password |
|---|---|---|
| Salon owner (Maison Beauty) | owner@maisonbeauty.om | Maison#2026 |
| Reception | reception@maisonbeauty.om | Maison#2026 |
| Artists | sarah@ / maryam@ / noor@maisonbeauty.om | Staff#2026 |
| Customer | customer@glowbook.app | Customer#2026 |
| Super admin | admin@glowbook.app | Glowbook#2026 |
| Second tenant (Velvet Hair Studio) | owner@velvethair.om | Velvet#2026 |

Seed: Maison Beauty with Sarah, Maryam, Noor; Soft Makeup OMR 25 / 60 min, Full Makeup OMR 35 /
90 min, Bridal Makeup OMR 75 / 120 min (OMR 20 deposit), Hair Styling OMR 20 / 60 min, plus Lash
Lift and Makeup Lesson; ~30 clients; ~800 bookings over the past 60 days and next 14; payments,
~230 reviews, lunch blocks, a vacation, National Day closure + special hours. The sign-in screen
shows one-tap demo chips unless built with `--dart-define=SHOW_DEMO_ACCOUNTS=false`.

### Tests

```bash
npm run test:api          # backend/, against a running API with the seed loaded (70 checks)
```
```bash
flutter test              # app/
```
```bash
npm run typecheck         # backend/
```
```bash
flutter analyze           # app/
```

---

## Deploying

**API → Vercel** (project root `backend/`). Set env vars from `.env.example` in Vercel
(Production/Preview). The build runs `prisma generate && prisma migrate deploy && next build`.
```bash
npx vercel --prod
```
Seed production once only if you want the demo (`npm run db:seed` with prod `DATABASE_URL`).
Cron: `vercel.json` runs `/api/cron/reminders` daily (Hobby limit); use
`.github/workflows/reminders.yml` or Vercel Pro for every 15 minutes. See `docs/NOTIFICATIONS.md`.

**Web app → Vercel** (project root `app/`, static): build locally/CI, then deploy `build/web`
(`app/vercel.json` rewrites every path to `index.html`, so `/salon/maison-beauty` works):
```bash
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-API.vercel.app --dart-define=APP_BASE_URL=https://YOUR-APP.vercel.app --dart-define=SHOW_DEMO_ACCOUNTS=false
```
Add the web origin to the API's `CORS_ORIGINS`.

**Mobile:** `flutter build apk` / `flutter build ipa` with the same `--dart-define`s.

---

## API

Envelope everywhere: `{ "success": true, "data": …, "message": null }` /
`{ "success": false, "data": null | {fields}, "message": "…" }`.

| Area | Endpoints |
|---|---|
| Auth | `POST /api/auth/register · register-salon · login · refresh · logout · forgot-password · reset-password · otp/request · otp/verify · oauth/google · oauth/apple` · `GET/PATCH /api/me` · `POST/DELETE /api/me/devices` |
| Discovery (public) | `GET /api/salons` · `GET /api/salons/:idOrSlug` · `GET /api/salons/:id/reviews` · `GET /api/availability` · `GET /api/availability/days` (`serviceIds=a,b` for a multi-service visit) |
| Customer booking | `POST /api/public/phone/request` · `POST /api/public/phone/verify` (→ phone token) · `POST /api/public/bookings` (`serviceIds[]`, `phoneToken`) · `GET /api/public/bookings/:id?token=` · `POST …/:id/cancel · reschedule · pay` |
| My account | `GET /api/my/bookings` · `GET /api/my/bookings/:id` · `POST …/:id/cancel · reschedule · pay · review` · `GET/POST /api/my/favorites` · `DELETE /api/my/favorites/:salonId` |
| Salon | `GET/PATCH /api/salon` · `GET/PUT /api/salon/hours` · `GET/POST /api/salon/holidays` · `DELETE …/:id` · `GET/POST /api/salon/members` · `PATCH/DELETE …/:id` · `GET/PUT /api/salon/templates` · `GET /api/salon/notification-log` · `POST /api/salons` |
| Catalogue & team | `GET/POST /api/services` · `GET/PATCH/DELETE /api/services/:id` · `GET/POST /api/service-categories` · `PATCH/DELETE …/:id` · `GET/POST /api/staff` · `GET/PATCH/DELETE /api/staff/:id` · `GET/POST /api/staff/:id/time-off` · `DELETE …/:timeOffId` |
| Clients | `GET/POST /api/customers` · `GET/PATCH /api/customers/:id` |
| Bookings | `GET/POST /api/bookings` · `GET/PATCH /api/bookings/:id` · `POST …/:id/cancel · reschedule · status · restore` · `GET/POST …/:id/payments` · `GET/POST /api/blocked-times` · `DELETE …/:id` |
| Views | `GET /api/dashboard` · `GET /api/calendar?from&to` · `GET /api/calendar/month?month` · `GET /api/reports?from&to` · `GET /api/reviews` · `POST /api/reviews/:id/reply` |
| Payments | `GET /api/payments` · `POST /api/payments/:id/settle` · `POST /api/payments/:id/test-confirm` (test gateway only) · `POST /api/payments/webhook/:provider` |
| Inbox | `GET /api/notifications` · `POST /api/notifications/:id/read` · `POST /api/notifications/read-all` |
| Platform | `GET /api/admin/salons` · `PATCH /api/admin/salons/:id` · `GET /api/admin/stats` |
| Jobs | `GET /api/cron/reminders` (Bearer `CRON_SECRET`) · `GET /api/health` |

---

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 1 | Architecture, Prisma/Neon, Vercel API, Flutter, auth, roles, salon setup | ✅ built & tested |
| 2 | Services, staff (shifts, leave, skills), clients CRM | ✅ |
| 3 | Booking engine, availability, calendar (day/week/month), conflict prevention | ✅ race-tested |
| 4 | Customer booking flow, public salon page, guest manage link | ✅ verified in browser |
| 5 | Notifications (in-app live; push/WhatsApp/email/SMS behind credentials), reminders cron | ✅ idempotency tested |
| 6 | Payments, deposits, cancellation policy, refunds | ✅ (test gateway) |
| 7 | Reports & analytics, reviews, retention | ✅ |

## Known issues / not yet done

- **Real payment gateway** not integrated — `PAYMENT_PROVIDER=test` is a sandbox (clearly labelled
  "Test mode" in the app). Implement `PaymentGateway` (Thawani / Stripe) + its webhook.
- **External channels need credentials** (FCM, WhatsApp, Resend, Twilio). Until then they are
  logged as `SKIPPED` — in-app notifications work now. The Flutter app has no
  `firebase_messaging` yet (needs your Firebase project files); `POST /api/me/devices` is ready.
- **Google/Apple sign-in** — backend verification is done; the Flutter buttons are not wired
  (needs OAuth client IDs + platform config).
- **Image uploads** (salon photos, staff photos) — URLs are supported everywhere, but there is no
  upload endpoint yet (Vercel Blob would fit). Salons without photos get generated cover art.
- **Rate limiting** is only applied to OTP and password reset; add an edge rate limiter
  (e.g. Upstash) for login before production.
- One service per booking (no multi-service baskets yet).
- Subscriptions: plan/status fields exist on `Salon`; no billing integration yet.
- Android/iOS builds not compiled on this machine (no Android SDK / macOS); web build verified.
