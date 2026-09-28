import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireSalon } from "@/lib/auth/context";
import { addDays, dayRange, localDate, localMinute } from "@/lib/time";
import { bookingSalonSelect } from "@/server/dto";

/** Salon home: greeting context, today's summary, today's schedule, 7-day revenue. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req);
  const now = new Date();
  const today = localDate(now, ctx.timezone);
  const { start, end } = dayRange(today, ctx.timezone);
  const mine = ctx.role === "STAFF" ? { staffId: ctx.staffId! } : {};
  const weekStart = dayRange(addDays(today, -6), ctx.timezone).start;

  const [salon, todays, paidToday, weekPayments, pendingRefunds, unread] = await Promise.all([
    db.salon.findUniqueOrThrow({ where: { id: ctx.salonId }, select: { name: true, nameAr: true, logoUrl: true, slug: true } }),
    db.booking.findMany({
      where: { salonId: ctx.salonId, startTime: { gte: start, lt: end }, ...mine },
      select: bookingSalonSelect,
      orderBy: { startTime: "asc" },
    }),
    db.payment.findMany({
      where: { salonId: ctx.salonId, status: "PAID", paidAt: { gte: start, lt: end }, ...(ctx.role === "STAFF" ? { booking: mine } : {}) },
      select: { amountBaisa: true, kind: true },
    }),
    ctx.role === "STAFF"
      ? Promise.resolve([])
      : db.payment.findMany({
          where: { salonId: ctx.salonId, status: "PAID", paidAt: { gte: weekStart, lt: end } },
          select: { amountBaisa: true, kind: true, paidAt: true },
        }),
    ctx.role === "STAFF" ? Promise.resolve(0) : db.payment.count({ where: { salonId: ctx.salonId, kind: "REFUND", status: "PENDING" } }),
    db.notification.count({ where: { userId: ctx.user.id, channel: "IN_APP", readAt: null } }),
  ]);

  const net = (rows: { amountBaisa: number; kind: string }[]) =>
    rows.reduce((s, p) => s + (p.kind === "REFUND" ? -p.amountBaisa : p.amountBaisa), 0);
  const count = (s: string) => todays.filter((b) => b.status === s).length;
  const live = todays.filter((b) => b.status !== "CANCELLED" && b.status !== "NO_SHOW");

  const week: { date: string; revenueBaisa: number }[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = addDays(today, -i);
    week.push({
      date: d,
      revenueBaisa: net(weekPayments.filter((p) => p.paidAt && localDate(p.paidAt, ctx.timezone) === d)),
    });
  }

  const nextUp = live.find((b) => b.startTime >= now && (b.status === "CONFIRMED" || b.status === "PENDING")) ?? null;

  return {
    salon,
    role: ctx.role,
    today,
    localMinute: localMinute(now, ctx.timezone),
    summary: {
      appointments: live.length,
      confirmed: count("CONFIRMED"),
      pending: count("PENDING"),
      arrived: count("ARRIVED") + count("IN_SERVICE"),
      completed: count("COMPLETED"),
      cancelled: count("CANCELLED"),
      noShow: count("NO_SHOW"),
      revenueBaisa: net(paidToday),
      expectedRevenueBaisa: live.reduce((s, b) => s + b.priceBaisa, 0),
    },
    schedule: todays,
    nextUp,
    week,
    pendingRefunds,
    unreadNotifications: unread,
  };
});
