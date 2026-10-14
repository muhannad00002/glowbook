import { db, type Tx } from "@/lib/db";
import { ApiError, badRequest, conflict, notFound } from "@/lib/http";
import { addDays, dateColumn, dateColumnToString, localDate, zonedToUtc } from "@/lib/time";
import type { Prisma } from "@/generated/prisma/client";
import type { TokenStatus } from "@/generated/prisma/enums";
import { newReference } from "@/server/booking/engine";
import { activeGateway } from "@/server/payments/service";

/**
 * Seasonal tokens — a numbered queue for busy seasons (Eid henna, etc.).
 *
 * An offering's day is cut into back-to-back token slots of `tokenMinutes` inside the
 * event's daily window; each slot seats `capacity` customers. Token numbers run in time
 * order: slot k seats numbers k·capacity+1 … k·capacity+capacity, so "#7" always comes
 * before "#8" in the queue.
 *
 * A new token is a PENDING_PAYMENT hold for HOLD_MINUTES. Paying the prepay amount
 * confirms it; an unpaid hold expires and frees its seat (the partial unique index on
 * live numbers makes the seat reusable). Seats are taken under an advisory lock on
 * (offering, date), and the unique index backs that up at the database level.
 */

export const TOKEN_HOLD_MINUTES = 15;
export const LIVE_TOKEN: TokenStatus[] = ["PENDING_PAYMENT", "CONFIRMED", "ARRIVED", "COMPLETED"];
const TX_OPTS = { timeout: 15_000, maxWait: 10_000 };

type OfferingWithEvent = Prisma.SeasonalOfferingGetPayload<{ include: { event: { include: { salon: true } } } }>;

export function prepayFor(o: { prepayMode: "FULL" | "FIXED"; prepayBaisa: number; priceBaisa: number }) {
  return o.prepayMode === "FULL" ? o.priceBaisa : Math.min(o.prepayBaisa, o.priceBaisa);
}

/** A seat counts while it is paid for, or still inside its payment hold. */
export function seatTakenWhere(now: Date): Prisma.SeasonalTokenWhereInput {
  return {
    OR: [
      { status: { in: ["CONFIRMED", "ARRIVED", "COMPLETED"] } },
      { status: "PENDING_PAYMENT", holdExpiresAt: { gt: now } },
    ],
  };
}

export async function loadOffering(offeringId: string): Promise<OfferingWithEvent> {
  const o = await db.seasonalOffering.findUnique({ where: { id: offeringId }, include: { event: { include: { salon: true } } } });
  if (!o) throw notFound("This offering doesn't exist.");
  return o;
}

/** Salon-local dates the event runs that are not over yet. */
export function eventDates(event: { startDate: Date; endDate: Date }, today: string): string[] {
  const out: string[] = [];
  let d = dateColumnToString(event.startDate);
  const end = dateColumnToString(event.endDate);
  if (d < today) d = today;
  for (let i = 0; d <= end && i < 62; i++, d = addDays(d, 1)) out.push(d);
  return out;
}

export type TokenSlot = { start: string; end: string; capacity: number; left: number; firstNumber: number };

function slotStarts(o: OfferingWithEvent, date: string) {
  const { event } = o;
  const tz = event.salon.timezone;
  const starts: { k: number; start: Date; end: Date }[] = [];
  for (let k = 0, m = event.openMinute; m + o.tokenMinutes <= event.closeMinute; k++, m += o.tokenMinutes) {
    starts.push({ k, start: zonedToUtc(date, m, tz), end: zonedToUtc(date, m + o.tokenMinutes, tz) });
  }
  return starts;
}

function assertBookable(o: OfferingWithEvent, date: string, now: Date) {
  const { event } = o;
  if (!o.isActive || !event.isActive || !event.salon.isPublished) throw badRequest("Tokens for this aren't available right now.");
  const first = dateColumnToString(event.startDate);
  const last = dateColumnToString(event.endDate);
  if (date < first || date > last) throw badRequest("That date is outside the event.");
  if (date < localDate(now, event.salon.timezone)) throw badRequest("That date has passed.");
}

/** Every token slot of a day with the seats still free. */
export async function tokenSlots(offeringId: string, date: string, now = new Date()): Promise<TokenSlot[]> {
  const o = await loadOffering(offeringId);
  assertBookable(o, date, now);
  const taken = await db.seasonalToken.groupBy({
    by: ["startTime"],
    where: { offeringId, date: dateColumn(date), ...seatTakenWhere(now) },
    _count: { _all: true },
  });
  const byStart = new Map(taken.map((t) => [t.startTime.getTime(), t._count._all]));
  return slotStarts(o, date)
    .filter((s) => s.start.getTime() > now.getTime())
    .map((s) => ({
      start: s.start.toISOString(),
      end: s.end.toISOString(),
      capacity: o.capacity,
      left: Math.max(0, o.capacity - (byStart.get(s.start.getTime()) ?? 0)),
      firstNumber: s.k * o.capacity + 1,
    }));
}

async function lockOfferingDay(tx: Tx, offeringId: string, date: string) {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`token:${offeringId}:${date}`}, 0))`;
}

/** Takes a seat for the customer and holds it while they pay. */
export async function createTokenHold(input: {
  offeringId: string;
  startTime: Date;
  customerId: string;
  notes?: string | null;
  now?: Date;
}) {
  const now = input.now ?? new Date();
  const o = await loadOffering(input.offeringId);
  const tz = o.event.salon.timezone;
  const date = localDate(input.startTime, tz);
  assertBookable(o, date, now);
  const slot = slotStarts(o, date).find((s) => s.start.getTime() === input.startTime.getTime());
  if (!slot) throw badRequest("Please choose one of the listed token times.");
  if (slot.start.getTime() <= now.getTime()) throw badRequest("That time has already passed.");

  const prepay = prepayFor(o);
  if (prepay <= 0) throw badRequest("This offering has no advance payment set up. Please contact the salon.");

  return db.$transaction(async (tx) => {
    await lockOfferingDay(tx, o.id, date);
    // Let lapsed holds go so their seats (and numbers) can be reused.
    await tx.seasonalToken.updateMany({
      where: { offeringId: o.id, date: dateColumn(date), status: "PENDING_PAYMENT", holdExpiresAt: { lte: now } },
      data: { status: "EXPIRED" },
    });
    // One live token per customer per slot.
    const mine = await tx.seasonalToken.findFirst({
      where: { offeringId: o.id, startTime: slot.start, customerId: input.customerId, status: { in: LIVE_TOKEN } },
    });
    if (mine) {
      if (mine.status === "PENDING_PAYMENT") return mine; // resume paying
      throw conflict("You already have a token at this time.");
    }
    const seats = await tx.seasonalToken.findMany({
      where: { offeringId: o.id, startTime: slot.start, status: { in: LIVE_TOKEN } },
      select: { number: true },
    });
    const used = new Set(seats.map((s) => s.number));
    let number = 0;
    for (let i = 1; i <= o.capacity; i++) {
      const n = slot.k * o.capacity + i;
      if (!used.has(n)) {
        number = n;
        break;
      }
    }
    if (!number) throw new ApiError(409, "This token time just filled up. Please pick another.", { reason: "FULL" });

    return tx.seasonalToken.create({
      data: {
        reference: newReference().replace("GB-", "TK-"),
        salonId: o.salonId,
        offeringId: o.id,
        customerId: input.customerId,
        date: dateColumn(date),
        number,
        startTime: slot.start,
        endTime: slot.end,
        status: "PENDING_PAYMENT",
        priceBaisa: o.priceBaisa,
        prepayBaisa: prepay,
        holdExpiresAt: new Date(now.getTime() + TOKEN_HOLD_MINUTES * 60_000),
        customerNotes: input.notes ?? null,
      },
    });
  }, TX_OPTS);
}

/** Opens a checkout for the token's prepay amount. */
export async function startTokenPayment(tokenId: string) {
  const gateway = activeGateway();
  if (!gateway) throw badRequest("Online payment isn't available yet. Please contact the salon.");
  const t = await db.seasonalToken.findUnique({
    where: { id: tokenId },
    include: { offering: { include: { event: { include: { salon: { select: { currency: true, name: true } } } } } }, customer: true },
  });
  if (!t) throw notFound("Token not found.");
  if (t.status !== "PENDING_PAYMENT") throw conflict(t.status === "EXPIRED" ? "This hold has expired. Please take a new token." : "Nothing is due for this token.");
  if (t.holdExpiresAt && t.holdExpiresAt <= new Date()) throw conflict("This hold has expired. Please take a new token.");
  if (t.paymentRef && t.paymentProvider === gateway.name) return t; // reuse the open checkout

  const checkout = await gateway.createCheckout({
    paymentId: t.id,
    amountBaisa: t.prepayBaisa,
    currency: t.offering.event.salon.currency,
    description: `${t.offering.name} · ${t.offering.event.salon.name} · ${t.reference}`,
    customerEmail: t.customer.email,
  });
  return db.seasonalToken.update({
    where: { id: t.id },
    data: { paymentProvider: gateway.name, paymentRef: checkout.providerRef },
  });
}

/**
 * Money arrived (gateway webhook, or the test gateway). Idempotent. A payment that lands
 * just after the hold lapsed still confirms the token if its seat is free; otherwise the
 * customer must be refunded by the salon.
 */
export async function markTokenPaid(tokenId: string, now = new Date()) {
  const t = await db.seasonalToken.findUnique({ where: { id: tokenId } });
  if (!t) throw notFound("Token not found.");
  if (t.status === "CONFIRMED" || t.status === "ARRIVED" || t.status === "COMPLETED") return { token: t, confirmed: false };
  if (t.status !== "PENDING_PAYMENT" && t.status !== "EXPIRED") throw conflict("This token is no longer active.");
  const date = dateColumnToString(t.date);
  return db.$transaction(async (tx) => {
    await lockOfferingDay(tx, t.offeringId, date);
    if (t.status === "EXPIRED") {
      const clash = await tx.seasonalToken.findFirst({
        where: { offeringId: t.offeringId, date: t.date, number: t.number, status: { in: LIVE_TOKEN }, id: { not: t.id } },
      });
      if (clash) throw conflict("Your hold expired and the seat was taken. The salon will refund your payment.");
    }
    const res = await tx.seasonalToken.updateMany({
      where: { id: t.id, status: { in: ["PENDING_PAYMENT", "EXPIRED"] } },
      data: { status: "CONFIRMED", paidBaisa: t.prepayBaisa, paidAt: now, holdExpiresAt: null },
    });
    const token = await tx.seasonalToken.findUniqueOrThrow({ where: { id: t.id } });
    return { token, confirmed: res.count === 1 };
  }, TX_OPTS);
}

const TRANSITIONS: Partial<Record<TokenStatus, TokenStatus[]>> = {
  PENDING_PAYMENT: ["CANCELLED"],
  CONFIRMED: ["ARRIVED", "NO_SHOW", "CANCELLED"],
  ARRIVED: ["COMPLETED", "CONFIRMED"],
  NO_SHOW: ["CONFIRMED"],
  COMPLETED: ["ARRIVED"],
};

/** Front desk moves a token through the queue. */
export async function setTokenStatus(input: { salonId: string; tokenId: string; status: TokenStatus; reason?: string | null }) {
  const t = await db.seasonalToken.findFirst({ where: { id: input.tokenId, salonId: input.salonId } });
  if (!t) throw notFound("Token not found.");
  if (!TRANSITIONS[t.status]?.includes(input.status)) throw badRequest(`A ${t.status.toLowerCase().replace("_", " ")} token can't become ${input.status.toLowerCase().replace("_", " ")}.`);
  const now = new Date();
  const data: Prisma.SeasonalTokenUpdateManyMutationInput = { status: input.status };
  if (input.status === "ARRIVED") data.arrivedAt = t.arrivedAt ?? now;
  if (input.status === "COMPLETED") data.completedAt = now;
  if (input.status === "CONFIRMED") {
    data.arrivedAt = null;
    data.completedAt = null;
  }
  if (input.status === "CANCELLED") {
    data.cancelledAt = now;
    data.cancelReason = input.reason ?? null;
  }
  const res = await db.seasonalToken.updateMany({ where: { id: t.id, status: t.status }, data });
  if (res.count !== 1) throw conflict("This token was just changed. Please refresh.");
  return { previous: t.status, token: await db.seasonalToken.findUniqueOrThrow({ where: { id: t.id } }) };
}

/** Cron: holds that ran out. */
export async function expireTokenHolds(now = new Date()) {
  const res = await db.seasonalToken.updateMany({
    where: { status: "PENDING_PAYMENT", holdExpiresAt: { lte: now } },
    data: { status: "EXPIRED" },
  });
  return res.count;
}
