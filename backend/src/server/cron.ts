import { db } from "@/lib/db";
import { cancelBooking } from "@/server/booking/engine";
import { notifyBookingEvent, notifyTokenEvent, retryFailed } from "@/server/notifications/service";
import { expireTokenHolds } from "@/server/seasonal/engine";
import { PAYMENT_HOLD_MINUTES } from "@/server/payments/service";

/**
 * One pass of the scheduled job (Vercel Cron → GET /api/cron/reminders).
 *
 * Every step is idempotent: reminders use a dedupe key that includes the booking's
 * start time, so a pass that runs twice — or overlaps another — sends nothing twice,
 * and a rescheduled booking correctly gets fresh reminders for its new time.
 */
export async function runScheduledJobs(now = new Date()) {
  const H = 3600_000;
  const result = { reminders24h: 0, reminders3h: 0, reviewRequests: 0, expiredHolds: 0, tokenReminders: 0, expiredTokenHolds: 0, retried: 0 };

  // 24-hour reminder: starts within the next day (but not within 3h), booked well ahead.
  const in24 = await db.booking.findMany({
    where: {
      status: "CONFIRMED",
      startTime: { gt: new Date(now.getTime() + 3 * H), lte: new Date(now.getTime() + 24 * H) },
      salon: { remind24h: true },
    },
    select: { id: true, startTime: true, createdAt: true },
    take: 500,
  });
  for (const b of in24) {
    if (b.createdAt.getTime() > b.startTime.getTime() - 20 * H) continue; // booked last-minute
    const ids = await notifyBookingEvent(b.id, "REMINDER_24H", { eventKey: b.startTime.toISOString() });
    if (ids.length) result.reminders24h++;
  }

  // 3-hour reminder.
  const in3 = await db.booking.findMany({
    where: {
      status: "CONFIRMED",
      startTime: { gt: now, lte: new Date(now.getTime() + 3 * H) },
      salon: { remind3h: true },
    },
    select: { id: true, startTime: true, createdAt: true },
    take: 500,
  });
  for (const b of in3) {
    if (b.createdAt.getTime() > b.startTime.getTime() - 2 * H) continue;
    const ids = await notifyBookingEvent(b.id, "REMINDER_3H", { eventKey: b.startTime.toISOString() });
    if (ids.length) result.reminders3h++;
  }

  // Review request an hour or more after a completed visit (within 3 days).
  const done = await db.booking.findMany({
    where: {
      status: "COMPLETED",
      completedAt: { gte: new Date(now.getTime() - 72 * H), lte: new Date(now.getTime() - 1 * H) },
      review: null,
      salon: { reviewRequests: true },
    },
    select: { id: true },
    take: 500,
  });
  for (const b of done) {
    const ids = await notifyBookingEvent(b.id, "REVIEW_REQUEST");
    if (ids.length) result.reviewRequests++;
  }

  // Release slots held for a deposit that never arrived.
  const stale = await db.booking.findMany({
    where: {
      status: "PENDING",
      paymentRequirement: { not: "NONE" },
      source: { in: ["CUSTOMER_APP", "PUBLIC_PAGE"] },
      createdAt: { lt: new Date(now.getTime() - PAYMENT_HOLD_MINUTES * 60_000) },
      payments: { none: { status: "PAID" } },
    },
    select: { id: true, salonId: true },
    take: 200,
  });
  for (const b of stale) {
    try {
      await cancelBooking({ salonId: b.salonId, bookingId: b.id, cancelledById: null, bySalon: true, reason: "Deposit not received in time" });
      await notifyBookingEvent(b.id, "BOOKING_CANCELLED", { notifySalon: true });
      result.expiredHolds++;
    } catch (e) {
      console.error("[cron] hold expiry failed", b.id, e);
    }
  }

  // Seasonal tokens: "your turn is in an hour". The window is a little over an hour so a
  // job that runs every 15 minutes reaches every token 50–65 minutes ahead.
  const soon = await db.seasonalToken.findMany({
    where: { status: "CONFIRMED", startTime: { gt: now, lte: new Date(now.getTime() + 65 * 60_000) } },
    select: { id: true, startTime: true, paidAt: true },
    take: 500,
  });
  for (const t of soon) {
    // Confirmed within the last hour before the token: the confirmation already says when.
    if (t.paidAt && t.paidAt.getTime() > t.startTime.getTime() - 60 * 60_000) continue;
    const ids = await notifyTokenEvent(t.id, "TOKEN_REMINDER_1H", { eventKey: t.startTime.toISOString() });
    if (ids.length) result.tokenReminders++;
  }
  result.expiredTokenHolds = await expireTokenHolds(now);

  result.retried = await retryFailed();
  return result;
}
