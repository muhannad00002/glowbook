/**
 * Demo data. Run with `npm run db:seed` (after migrations).
 *
 * Creates the platform notification templates, then — only if it doesn't exist yet —
 * Maison Beauty (Sarah, Maryam, Noor; the four signature services plus two more),
 * ~30 clients and two months of realistic history + two weeks of upcoming bookings,
 * plus two smaller salons so discovery and tenant isolation have something to show.
 *
 * Bookings are placed inside each artist's real working hours (the same `buildDay` the
 * booking engine uses), so the seed never violates the no-overlap constraint.
 */
import "dotenv/config";
import bcrypt from "bcryptjs";
import { db } from "../src/lib/db";
import { addDays, localDate, zonedToUtc, dateColumn } from "../src/lib/time";
import { buildDay, loadAvailabilityData } from "../src/server/booking/availability";
import { newReference } from "../src/server/booking/engine";
import { DEFAULT_TEMPLATES } from "../src/server/notifications/templates";
import { WHATSAPP_TEMPLATE_NAMES } from "../src/server/notifications/providers";
import { refreshSalonRating } from "../src/server/reviews";
import type { Prisma, Service } from "../src/generated/prisma/client";
import type { BookingStatus, NotificationChannel, NotificationType, PaymentMethod } from "../src/generated/prisma/enums";

const TZ = "Asia/Muscat";
const OMR = (n: number) => Math.round(n * 1000);
const H = (h: number, m = 0) => h * 60 + m;

// Deterministic pseudo-random so every seed run produces the same shape of data.
let seedState = 20260928;
const rand = () => {
  seedState = (seedState * 1664525 + 1013904223) % 4294967296;
  return seedState / 4294967296;
};
const pick = <T>(arr: T[]) => arr[Math.floor(rand() * arr.length)];
const chance = (p: number) => rand() < p;

async function seedTemplates() {
  const channels: NotificationChannel[] = ["IN_APP", "PUSH", "WHATSAPP", "EMAIL", "SMS"];
  let n = 0;
  let updated = 0;
  for (const [type, byLocale] of Object.entries(DEFAULT_TEMPLATES) as [NotificationType, (typeof DEFAULT_TEMPLATES)[NotificationType]][]) {
    for (const locale of ["en", "ar"] as const) {
      for (const channel of channels) {
        const existing = await db.notificationTemplate.findFirst({ where: { salonId: null, type, channel, locale } });
        if (existing) {
          // Keep platform defaults current (salon overrides have their own rows).
          if (existing.body !== byLocale[locale].body || existing.subject !== byLocale[locale].title) {
            await db.notificationTemplate.update({ where: { id: existing.id }, data: { subject: byLocale[locale].title, body: byLocale[locale].body } });
            updated++;
          }
          continue;
        }
        await db.notificationTemplate.create({
          data: {
            salonId: null,
            type,
            channel,
            locale,
            subject: byLocale[locale].title,
            body: byLocale[locale].body,
            whatsappTemplateName: channel === "WHATSAPP" ? (WHATSAPP_TEMPLATE_NAMES[type] ?? null) : null,
          },
        });
        n++;
      }
    }
  }
  console.log(`✓ notification templates (${n} new, ${updated} updated)`);
}

async function user(email: string, name: string, password: string, extra: Partial<Prisma.UserCreateInput> = {}) {
  return db.user.upsert({
    where: { email },
    create: { email, name, passwordHash: await bcrypt.hash(password, 11), emailVerifiedAt: new Date(), ...extra },
    update: {},
  });
}

const CUSTOMER_NAMES = [
  "Aisha Al-Balushi", "Fatma Al-Harthy", "Maha Al-Said", "Reem Al-Hinai", "Shamsa Al-Rawahi", "Huda Al-Lawati",
  "Asma Al-Busaidi", "Salma Al-Kindi", "Laila Al-Zadjali", "Noora Al-Maskari", "Hind Al-Farsi", "Zainab Al-Ajmi",
  "Muna Al-Riyami", "Amal Al-Siyabi", "Rawan Al-Shukaili", "Dana Al-Wahaibi", "Sara Al-Mahrouqi", "Khadija Al-Ghafri",
  "Buthaina Al-Jabri", "Iman Al-Toubi", "Wafa Al-Nabhani", "Yusra Al-Mamari", "Hanan Al-Qasmi", "Noof Al-Hashmi",
  "Jamila Al-Ismaili", "Afra Al-Kharusi", "Ruqaya Al-Saadi", "Latifa Al-Mandhari", "Ghalia Al-Amri", "Mariam Al-Abri",
];

const REVIEW_COMMENTS = [
  "Absolutely loved my look — soft, glowy and lasted all night 💕",
  "Maryam is a magician. My bridal makeup was exactly what I dreamed of.",
  "So calm and welcoming. Will definitely be back!",
  "Beautiful salon and the team is so gentle. Highly recommend.",
  "My hair stayed perfect through the whole wedding. Thank you Noor!",
  "Sarah listened to everything I wanted. Perfect soft glam.",
  "كانت التجربة رائعة والمكياج ناعم جداً 🤍",
  "أفضل صالون في مسقط، شكراً لكم!",
  "Lovely experience, on time and very professional.",
  null,
];

async function seedMaison(now: Date) {
  const existing = await db.salon.findUnique({ where: { slug: "maison-beauty" } });
  if (existing) {
    console.log("• Maison Beauty already exists — skipping demo data");
    return;
  }

  const owner = await user("owner@maisonbeauty.om", "Layla Al-Harthy", "Maison#2026", { phone: "+96891000001" });
  const reception = await user("reception@maisonbeauty.om", "Huda Al-Kindi", "Maison#2026");
  const sarahU = await user("sarah@maisonbeauty.om", "Sarah Al-Balushi", "Staff#2026");
  const maryamU = await user("maryam@maisonbeauty.om", "Maryam Al-Hinai", "Staff#2026");
  const noorU = await user("noor@maisonbeauty.om", "Noor Al-Rawahi", "Staff#2026");
  const customerU = await user("customer@glowbook.app", "Aisha Al-Balushi", "Customer#2026", {
    phone: "+96899112233",
    phoneVerifiedAt: new Date(),
  });

  const salon = await db.salon.create({
    data: {
      slug: "maison-beauty",
      name: "Maison Beauty",
      nameAr: "ميزون بيوتي",
      tagline: "Soft glam & bridal artistry in Muscat",
      taglineAr: "مكياج ناعم وإطلالات عرائس في مسقط",
      description:
        "A calm, light-filled studio for soft glam, bridal and hair styling. Our artists specialise in skin-first makeup that looks like you — just glowing.",
      descriptionAr: "استوديو هادئ ومشرق للمكياج الناعم وإطلالات العرائس وتصفيف الشعر. فنانتنا متخصصات في مكياج يبرز جمالك الطبيعي.",
      category: "MAKEUP",
      phone: "+96824000000",
      whatsapp: "+96891000000",
      email: "hello@maisonbeauty.om",
      address: "Al Mouj Street, The Wave, Muscat",
      addressAr: "شارع الموج، الموج، مسقط",
      city: "Muscat",
      latitude: 23.6203,
      longitude: 58.2807,
      timezone: TZ,
      slotIntervalMinutes: 15,
      minNoticeMinutes: 60,
      bookingHorizonDays: 60,
      autoConfirm: true,
      cancellationWindowHours: 24,
      lateCancellationFeeBaisa: OMR(5),
      depositPolicy: "REFUNDABLE_IN_WINDOW",
      notifyWhatsapp: true,
      notifyEmail: true,
      notifySms: false,
      plan: "PRO",
      subscriptionStatus: "ACTIVE",
      workingHours: {
        create: [6, 0, 1, 2, 3, 4].map((d) => ({ dayOfWeek: d, openMinute: H(9), closeMinute: H(21) })).concat([{ dayOfWeek: 5, openMinute: H(14), closeMinute: H(22) }]),
      },
    },
  });

  await db.salonMember.createMany({
    data: [
      { salonId: salon.id, userId: owner.id, role: "OWNER" },
      { salonId: salon.id, userId: reception.id, role: "RECEPTIONIST" },
      { salonId: salon.id, userId: sarahU.id, role: "STAFF" },
      { salonId: salon.id, userId: maryamU.id, role: "STAFF" },
      { salonId: salon.id, userId: noorU.id, role: "STAFF" },
    ],
  });

  const [makeup, hair, bridal] = await Promise.all([
    db.serviceCategory.create({ data: { salonId: salon.id, name: "Makeup", nameAr: "مكياج", sortOrder: 0 } }),
    db.serviceCategory.create({ data: { salonId: salon.id, name: "Hair", nameAr: "شعر", sortOrder: 1 } }),
    db.serviceCategory.create({ data: { salonId: salon.id, name: "Bridal", nameAr: "عرائس", sortOrder: 2 } }),
  ]);

  const shift = (days: number[], start: number, end: number) => days.map((d) => ({ dayOfWeek: d, startMinute: start, endMinute: end }));
  const sarah = await db.staff.create({
    data: {
      salonId: salon.id, userId: sarahU.id, name: "Sarah", nameAr: "سارة", title: "Senior Makeup Artist", titleAr: "خبيرة مكياج أولى",
      bio: "Skin-first soft glam. 9 years behind the brush.", color: "#8E4B61", sortOrder: 0, phone: "+96891000011", email: "sarah@maisonbeauty.om",
      hours: { create: [...shift([6, 0, 1, 2, 3], H(9), H(17)), ...shift([4], H(12), H(20))].map((h) => ({ ...h, salonId: salon.id })) },
    },
  });
  const maryam = await db.staff.create({
    data: {
      salonId: salon.id, userId: maryamU.id, name: "Maryam", nameAr: "مريم", title: "Bridal Specialist", titleAr: "متخصصة عرائس",
      bio: "Bridal looks that photograph beautifully and last all night.", color: "#B7835A", sortOrder: 1, phone: "+96891000012", email: "maryam@maisonbeauty.om",
      hours: { create: [...shift([0, 1, 2, 3, 4], H(12), H(21)), ...shift([5], H(14), H(22))].map((h) => ({ ...h, salonId: salon.id })) },
    },
  });
  const noor = await db.staff.create({
    data: {
      salonId: salon.id, userId: noorU.id, name: "Noor", nameAr: "نور", title: "Hair & Makeup Artist", titleAr: "فنانة شعر ومكياج",
      bio: "Soft waves, sleek buns and everything in between.", color: "#5E7F73", sortOrder: 2, phone: "+96891000013", email: "noor@maisonbeauty.om",
      hours: { create: [...shift([6, 1, 2, 3, 4], H(10), H(19)), ...shift([5], H(14), H(22))].map((h) => ({ ...h, salonId: salon.id })) },
    },
  });

  type Svc = { name: string; nameAr: string; desc: string; descAr: string; cat: string; price: number; dur: number; buf: number; staff: string[]; deposit?: number };
  const defs: Svc[] = [
    { name: "Soft Makeup", nameAr: "مكياج ناعم", desc: "Luminous, skin-first glam for any occasion.", descAr: "مكياج مشرق وناعم لكل المناسبات.", cat: makeup.id, price: 25, dur: 60, buf: 15, staff: [sarah.id, maryam.id, noor.id] },
    { name: "Full Makeup", nameAr: "مكياج كامل", desc: "Full-coverage evening glam with lashes.", descAr: "مكياج سهرة كامل مع الرموش.", cat: makeup.id, price: 35, dur: 90, buf: 15, staff: [sarah.id, maryam.id] },
    { name: "Bridal Makeup", nameAr: "مكياج عروس", desc: "Your wedding-day look, trial notes included.", descAr: "إطلالتك في يوم زفافك مع ملاحظات التجربة.", cat: bridal.id, price: 75, dur: 120, buf: 30, staff: [maryam.id, sarah.id], deposit: 20 },
    { name: "Hair Styling", nameAr: "تصفيف شعر", desc: "Blow-outs, waves, updos and sleek buns.", descAr: "سشوار، تموجات، تسريحات مرفوعة.", cat: hair.id, price: 20, dur: 60, buf: 10, staff: [noor.id, maryam.id] },
    { name: "Lash Lift & Tint", nameAr: "رفع وصبغ الرموش", desc: "Lifted, defined lashes for 6–8 weeks.", descAr: "رموش مرفوعة ومحددة لمدة ٦-٨ أسابيع.", cat: makeup.id, price: 18, dur: 45, buf: 15, staff: [noor.id] },
    { name: "Makeup Lesson", nameAr: "درس مكياج", desc: "One-to-one lesson using your own kit.", descAr: "درس خاص باستخدام أدواتك.", cat: makeup.id, price: 40, dur: 90, buf: 15, staff: [sarah.id] },
  ];
  const services: Service[] = [];
  for (const [i, d] of defs.entries()) {
    services.push(
      await db.service.create({
        data: {
          salonId: salon.id, categoryId: d.cat, name: d.name, nameAr: d.nameAr, description: d.desc, descriptionAr: d.descAr,
          priceBaisa: OMR(d.price), durationMinutes: d.dur, bufferMinutes: d.buf, sortOrder: i,
          paymentRequirement: d.deposit ? "DEPOSIT" : "NONE", depositBaisa: d.deposit ? OMR(d.deposit) : 0,
          staff: { create: d.staff.map((staffId) => ({ staffId, salonId: salon.id })) },
        },
      }),
    );
  }

  // Clients. The first one is the demo customer account (verified phone → linked).
  const customers = [];
  for (const [i, name] of CUSTOMER_NAMES.entries()) {
    const phone = i === 0 ? "+96899112233" : `+9689${String(1200000 + i * 7919).slice(0, 7)}`;
    const email = i % 3 === 0 ? `${name.split(" ")[0].toLowerCase()}${i}@example.com` : null;
    customers.push(
      await db.customer.create({
        data: {
          salonId: salon.id, userId: i === 0 ? customerU.id : null, name, phone, email: i === 0 ? "customer@glowbook.app" : email,
          source: pick(["APP", "PUBLIC_PAGE", "WALK_IN", "ADMIN"] as const),
          birthday: chance(0.5) ? dateColumn(`19${88 + (i % 11)}-${String((i % 12) + 1).padStart(2, "0")}-${String((i % 27) + 1).padStart(2, "0")}`) : null,
          notes: i === 0 ? "Prefers dewy finish. Sensitive to strong fragrance." : i === 4 ? "Bride — wedding in December. Trial booked." : chance(0.2) ? "Likes a natural brow." : null,
          preferredStaffId: i % 4 === 0 ? sarah.id : i % 4 === 1 ? maryam.id : null,
          createdAt: new Date(now.getTime() - (70 - (i % 60)) * 86400_000),
        },
      }),
    );
  }

  // Leave, closures and blocked time — these shape availability too.
  const today = localDate(now, TZ);
  await db.staffTimeOff.create({
    data: { salonId: salon.id, staffId: maryam.id, startTime: zonedToUtc(addDays(today, 10), 0, TZ), endTime: zonedToUtc(addDays(today, 13), 0, TZ), type: "VACATION", reason: "Family trip" },
  });
  await db.salonHoliday.create({ data: { salonId: salon.id, date: dateColumn("2026-11-18"), name: "National Day", isClosed: true } });
  await db.salonHoliday.create({ data: { salonId: salon.id, date: dateColumn("2026-11-19"), name: "National Day (short hours)", isClosed: false, openMinute: H(16), closeMinute: H(21) } });
  for (let i = 0; i <= 14; i++) {
    const d = addDays(today, i);
    await db.blockedTime.create({
      data: { salonId: salon.id, staffId: sarah.id, startTime: zonedToUtc(d, H(13), TZ), endTime: zonedToUtc(d, H(13, 30), TZ), type: "LUNCH", note: "Lunch" },
    });
  }
  await db.blockedTime.create({
    data: { salonId: salon.id, staffId: noor.id, startTime: zonedToUtc(addDays(today, 1), H(10), TZ), endTime: zonedToUtc(addDays(today, 1), H(11), TZ), type: "MEETING", note: "Product training" },
  });

  // ---- Bookings ------------------------------------------------------------
  const staffIds = [sarah.id, maryam.id, noor.id];
  const from = addDays(today, -60);
  const to = addDays(today, 14);
  const data = await loadAvailabilityData(db, { id: salon.id, timezone: TZ, slotIntervalMinutes: 15, minNoticeMinutes: 60, bookingHorizonDays: 60 }, staffIds, from, to);
  const offered = new Map(staffIds.map((id) => [id, services.filter((s) => defs[services.indexOf(s)].staff.includes(id))]));

  const bookingRows: Prisma.BookingCreateManyInput[] = [];
  const historyRows: Prisma.BookingStatusHistoryCreateManyInput[] = [];
  const paymentRows: Prisma.PaymentCreateManyInput[] = [];
  const refs = new Set<string>();
  const step = 15 * 60_000;
  const nowMs = now.getTime();

  for (let d = from; d <= to; d = addDays(d, 1)) {
    const plan = buildDay(data, d);
    const isToday = d === today;
    const future = d > today;
    const fill = isToday ? 0.8 : future ? Math.max(0.15, 0.6 - (addDaysDiff(today, d) * 0.03)) : 0.62;
    for (const s of plan.staff) {
      for (const w of s.work) {
        let t = w.start;
        while (t < w.end) {
          const svc = pick(offered.get(s.staffId)!);
          const dur = svc.durationMinutes * 60_000;
          const buf = svc.bufferMinutes * 60_000;
          const free = s.busy.every((b) => b.end <= t || b.start >= t + dur + buf);
          if (t + dur <= w.end && free && chance(fill)) {
            const start = t;
            const end = t + dur;
            const customer = customers[Math.floor(Math.pow(rand(), 1.6) * customers.length)]; // regulars book more
            let status: BookingStatus;
            if (end <= nowMs) status = chance(0.86) ? "COMPLETED" : chance(0.55) ? "CANCELLED" : "NO_SHOW";
            else if (start <= nowMs) status = "IN_SERVICE";
            else if (isToday && start - nowMs < 45 * 60_000) status = "ARRIVED";
            else status = chance(0.1) ? "CANCELLED" : chance(0.14) ? "PENDING" : "CONFIRMED";
            if (svc.paymentRequirement === "DEPOSIT" && status === "PENDING") status = "CONFIRMED";

            let ref = newReference();
            while (refs.has(ref)) ref = newReference();
            refs.add(ref);
            const id = crypto.randomUUID();
            const createdAt = new Date(Math.min(nowMs - 3600_000, start - (2 + Math.floor(rand() * 14)) * 86400_000));
            const deposit = svc.paymentRequirement === "DEPOSIT" ? svc.depositBaisa : 0;
            let paid = 0;
            const methods: PaymentMethod[] = ["CARD", "CARD", "CASH", "CASH", "BANK_TRANSFER"];

            if (deposit && status !== "CANCELLED") {
              paymentRows.push({ salonId: salon.id, bookingId: id, customerId: customer.id, amountBaisa: deposit, method: chance(0.6) ? "ONLINE" : "BANK_TRANSFER", kind: "DEPOSIT", status: "PAID", paidAt: new Date(createdAt.getTime() + 600_000), provider: "test", createdAt });
              paid += deposit;
            }
            if (status === "COMPLETED") {
              const rest = svc.priceBaisa - paid;
              paymentRows.push({ salonId: salon.id, bookingId: id, customerId: customer.id, amountBaisa: rest, method: pick(methods), kind: deposit ? "BALANCE" : "FULL", status: "PAID", paidAt: new Date(end), createdAt: new Date(end) });
              paid += rest;
            }

            bookingRows.push({
              id, reference: ref, salonId: salon.id, customerId: customer.id, staffId: s.staffId, serviceId: svc.id,
              startTime: new Date(start), endTime: new Date(end), blockedUntil: new Date(end + buf), status,
              source: pick(["CUSTOMER_APP", "PUBLIC_PAGE", "PUBLIC_PAGE", "WALK_IN", "ADMIN"] as const),
              priceBaisa: svc.priceBaisa, paymentRequirement: svc.paymentRequirement, depositBaisa: deposit, paidBaisa: paid,
              customerNotes: chance(0.12) ? pick(["Please keep it natural 🤍", "I have an event at 8pm", "Sensitive skin", "Bringing a reference photo"]) : null,
              internalNotes: chance(0.08) ? pick(["Regular — offer tea", "Allergic to latex sponges", "VIP"]) : null,
              cancelledAt: status === "CANCELLED" ? new Date(Math.min(nowMs, start - 86400_000)) : null,
              cancelReason: status === "CANCELLED" ? pick(["Change of plans", "Feeling unwell", "Event postponed"]) : null,
              completedAt: status === "COMPLETED" ? new Date(end) : null,
              createdAt,
            });
            historyRows.push({ salonId: salon.id, bookingId: id, kind: "CREATED", toStatus: status === "PENDING" ? "PENDING" : "CONFIRMED", newStartTime: new Date(start), newEndTime: new Date(end), newStaffId: s.staffId, createdAt });
            if (!["PENDING", "CONFIRMED"].includes(status)) {
              historyRows.push({ salonId: salon.id, bookingId: id, kind: "STATUS_CHANGE", fromStatus: "CONFIRMED", toStatus: status, createdAt: new Date(Math.min(nowMs, end)) });
            }
            s.busy.push({ start, end: end + buf });
            t = Math.ceil((end + buf) / step) * step;
          } else {
            t += step * (1 + Math.floor(rand() * 3));
          }
        }
      }
    }
  }

  await db.booking.createMany({ data: bookingRows });
  await db.bookingStatusHistory.createMany({ data: historyRows });
  await db.payment.createMany({ data: paymentRows });

  // Make sure the demo customer account has something upcoming and something to review.
  const aisha = customers[0];
  const upcomingForAisha = bookingRows.filter((b) => b.customerId === aisha.id && new Date(b.startTime as Date).getTime() > nowMs && b.status === "CONFIRMED");
  if (upcomingForAisha.length === 0) {
    const candidate = bookingRows.find((b) => new Date(b.startTime as Date).getTime() > nowMs + 2 * 86400_000 && b.status === "CONFIRMED");
    if (candidate) await db.booking.update({ where: { id: candidate.id! }, data: { customerId: aisha.id } });
  }
  const lastDone = bookingRows.filter((b) => b.status === "COMPLETED").at(-1);
  if (lastDone) {
    await db.booking.update({ where: { id: lastDone.id! }, data: { customerId: aisha.id } });
    await db.payment.updateMany({ where: { bookingId: lastDone.id! }, data: { customerId: aisha.id } });
  }

  // Reviews on ~40% of completed visits (not the one kept for the demo customer to write).
  const completed = await db.booking.findMany({ where: { salonId: salon.id, status: "COMPLETED", id: { not: lastDone?.id } }, select: { id: true, customerId: true, staffId: true, completedAt: true } });
  const reviewRows: Prisma.ReviewCreateManyInput[] = [];
  for (const b of completed) {
    if (!chance(0.4)) continue;
    const rating = chance(0.72) ? 5 : chance(0.75) ? 4 : 3;
    const comment = pick(REVIEW_COMMENTS);
    reviewRows.push({
      salonId: salon.id, bookingId: b.id, customerId: b.customerId, staffId: b.staffId, rating, comment,
      reply: rating >= 5 && chance(0.25) ? "Thank you so much — see you soon! 💕" : null,
      createdAt: new Date((b.completedAt ?? now).getTime() + 6 * 3600_000),
    });
  }
  await db.review.createMany({ data: reviewRows });
  await refreshSalonRating(salon.id);

  // A populated inbox for the owner and the demo customer.
  const recent = await db.booking.findMany({
    where: { salonId: salon.id, startTime: { gte: now } },
    orderBy: { createdAt: "desc" },
    take: 8,
    include: { customer: true, service: true, staff: true },
  });
  for (const [i, b] of recent.entries()) {
    const when = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }).format(b.startTime);
    await db.notification.create({
      data: {
        salonId: salon.id, bookingId: b.id, userId: owner.id, type: "BOOKING_CREATED", channel: "IN_APP", status: "SENT",
        title: `New booking · ${b.customer.name}`, body: `${b.service.name} · ${when} with ${b.staff.name}`,
        dedupeKey: `seed:${b.id}:owner`, sentAt: new Date(nowMs - i * 3_600_000), readAt: i > 2 ? new Date() : null,
        createdAt: new Date(nowMs - i * 3_600_000),
      },
    });
  }
  const aishaNext = await db.booking.findFirst({ where: { customerId: aisha.id, startTime: { gte: now }, status: "CONFIRMED" }, orderBy: { startTime: "asc" }, include: { service: true, staff: true } });
  if (aishaNext) {
    const when = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, weekday: "short", day: "numeric", month: "short" }).format(aishaNext.startTime);
    const time = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "numeric", minute: "2-digit" }).format(aishaNext.startTime);
    await db.notification.create({
      data: {
        salonId: salon.id, bookingId: aishaNext.id, userId: customerU.id, customerId: aisha.id, type: "BOOKING_CONFIRMED", channel: "IN_APP", status: "SENT",
        title: "Appointment confirmed 💕", body: `Hi Aisha 💕 Your appointment at Maison Beauty is confirmed for ${when} at ${time} with ${aishaNext.staff.name}. Ref ${aishaNext.reference}.`,
        dedupeKey: `seed:${aishaNext.id}:confirmed`, sentAt: new Date(nowMs - 2 * 86400_000), createdAt: new Date(nowMs - 2 * 86400_000),
      },
    });
  }

  const todayCount = bookingRows.filter((b) => localDate(b.startTime as Date, TZ) === today).length;
  console.log(`✓ Maison Beauty: ${services.length} services, ${customers.length} clients, ${bookingRows.length} bookings (${todayCount} today), ${paymentRows.length} payments, ${reviewRows.length} reviews`);
}

function addDaysDiff(a: string, b: string) {
  return Math.round((Date.parse(b) - Date.parse(a)) / 86400_000);
}

async function seedSmallSalon(opts: {
  slug: string; name: string; nameAr: string; tagline: string; category: "HAIR" | "ARTIST"; ownerEmail: string; ownerName: string; password: string;
  staff: { name: string; nameAr: string; title: string; color: string }[];
  services: { name: string; nameAr: string; price: number; dur: number }[];
}, now: Date) {
  if (await db.salon.findUnique({ where: { slug: opts.slug } })) return;
  const owner = await user(opts.ownerEmail, opts.ownerName, opts.password);
  const salon = await db.salon.create({
    data: {
      slug: opts.slug, name: opts.name, nameAr: opts.nameAr, tagline: opts.tagline, category: opts.category, city: "Muscat", timezone: TZ,
      address: "Qurum, Muscat", phone: "+96824111111",
      workingHours: { create: [6, 0, 1, 2, 3, 4].map((d) => ({ dayOfWeek: d, openMinute: H(10), closeMinute: H(20) })) },
      members: { create: { userId: owner.id, role: "OWNER" } },
    },
  });
  const staff = [];
  for (const [i, s] of opts.staff.entries()) {
    staff.push(await db.staff.create({
      data: {
        salonId: salon.id, name: s.name, nameAr: s.nameAr, title: s.title, color: s.color, sortOrder: i,
        hours: { create: [6, 0, 1, 2, 3, 4].map((d) => ({ dayOfWeek: d, startMinute: H(10), endMinute: H(20), salonId: salon.id })) },
      },
    }));
  }
  const svcs = [];
  for (const [i, s] of opts.services.entries()) {
    svcs.push(await db.service.create({
      data: {
        salonId: salon.id, name: s.name, nameAr: s.nameAr, priceBaisa: OMR(s.price), durationMinutes: s.dur, bufferMinutes: 10, sortOrder: i,
        staff: { create: staff.map((st) => ({ staffId: st.id, salonId: salon.id })) },
      },
    }));
  }
  const c = await db.customer.create({ data: { salonId: salon.id, name: "Reem Al-Hinai", phone: "+96895550001", source: "WALK_IN" } });
  // A few completed visits with reviews so the discovery card has a rating.
  for (let i = 1; i <= 3; i++) {
    const day = addDays(localDate(now, TZ), -i * 3);
    const start = zonedToUtc(day, H(11), TZ);
    const svc = svcs[i % svcs.length];
    const end = new Date(start.getTime() + svc.durationMinutes * 60_000);
    const b = await db.booking.create({
      data: {
        reference: newReference(), salonId: salon.id, customerId: c.id, staffId: staff[0].id, serviceId: svc.id,
        startTime: start, endTime: end, blockedUntil: new Date(end.getTime() + 600_000), status: "COMPLETED", source: "WALK_IN",
        priceBaisa: svc.priceBaisa, paidBaisa: svc.priceBaisa, completedAt: end,
      },
    });
    await db.payment.create({ data: { salonId: salon.id, bookingId: b.id, customerId: c.id, amountBaisa: svc.priceBaisa, method: "CARD", kind: "FULL", status: "PAID", paidAt: end } });
    await db.review.create({ data: { salonId: salon.id, bookingId: b.id, customerId: c.id, staffId: staff[0].id, rating: i === 2 ? 4 : 5, comment: "Lovely team and beautiful results." } });
  }
  await refreshSalonRating(salon.id);
  console.log(`✓ ${opts.name}`);
}

async function main() {
  const now = new Date();
  await seedTemplates();
  await user("admin@glowbook.app", "Glowbook Admin", "Glowbook#2026", { isSuperAdmin: true });
  await seedMaison(now);
  await seedSmallSalon({
    slug: "velvet-hair-studio", name: "Velvet Hair Studio", nameAr: "فيلفيت لتصفيف الشعر", tagline: "Colour, cuts & glossy blow-dries",
    category: "HAIR", ownerEmail: "owner@velvethair.om", ownerName: "Dana Al-Wahaibi", password: "Velvet#2026",
    staff: [{ name: "Rania", nameAr: "رانيا", title: "Colourist", color: "#6B5B95" }, { name: "Hala", nameAr: "هالة", title: "Stylist", color: "#A0707A" }],
    services: [{ name: "Blow-dry", nameAr: "سشوار", price: 12, dur: 45 }, { name: "Hair Colour", nameAr: "صبغة شعر", price: 45, dur: 120 }, { name: "Keratin Treatment", nameAr: "كيراتين", price: 60, dur: 150 }],
  }, now);
  await seedSmallSalon({
    slug: "rose-and-rouge", name: "Rose & Rouge Artistry", nameAr: "روز آند روج", tagline: "On-location bridal makeup artist",
    category: "ARTIST", ownerEmail: "hello@roseandrouge.om", ownerName: "Salma Al-Kindi", password: "Rouge#2026",
    staff: [{ name: "Salma", nameAr: "سلمى", title: "Makeup Artist", color: "#9C5B6E" }],
    services: [{ name: "Engagement Makeup", nameAr: "مكياج خطوبة", price: 55, dur: 90 }, { name: "Party Glam", nameAr: "مكياج حفلات", price: 30, dur: 60 }],
  }, now);
  console.log("\nDemo logins (development only):");
  console.log("  Salon owner  owner@maisonbeauty.om / Maison#2026");
  console.log("  Reception    reception@maisonbeauty.om / Maison#2026");
  console.log("  Staff        sarah@maisonbeauty.om / Staff#2026  (also maryam@, noor@)");
  console.log("  Customer     customer@glowbook.app / Customer#2026");
  console.log("  Super admin  admin@glowbook.app / Glowbook#2026");
}

main()
  .then(() => db.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await db.$disconnect();
    process.exit(1);
  });
