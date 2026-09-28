import { db, type Tx } from "@/lib/db";
import { badRequest, conflict, notFound } from "@/lib/http";
import { randomToken } from "@/lib/auth/tokens";
import type { PaymentKind, PaymentMethod } from "@/generated/prisma/enums";

/**
 * Payment architecture
 * --------------------
 * - Every money movement is a Payment row (deposits, balances, fees, refunds).
 * - Desk payments (cash / card terminal / bank transfer) are recorded as PAID at once.
 * - Online payments go through a `PaymentGateway`: we create a PENDING row, the gateway
 *   returns a checkout, and the gateway's webhook (or the test gateway) marks it PAID.
 * - `Booking.paidBaisa` is a denormalised net total recomputed after every change.
 *
 * To go live, implement `PaymentGateway` for your provider (e.g. Thawani, Stripe),
 * register it in `gateways`, set PAYMENT_PROVIDER, and route its webhook to
 * /api/payments/webhook/[provider].
 */

export interface PaymentGateway {
  name: string;
  createCheckout(input: {
    paymentId: string;
    amountBaisa: number;
    currency: string;
    description: string;
    customerEmail?: string | null;
  }): Promise<{ providerRef: string; checkoutUrl: string | null }>;
}

/** Sandbox gateway: no money moves. Only active when PAYMENT_PROVIDER=test. */
const testGateway: PaymentGateway = {
  name: "test",
  async createCheckout() {
    return { providerRef: `test_${randomToken(12)}`, checkoutUrl: null };
  },
};

const gateways: Record<string, PaymentGateway> = { test: testGateway };

export function activeGateway(): PaymentGateway | null {
  const name = process.env.PAYMENT_PROVIDER?.trim();
  return (name && gateways[name]) || null;
}

export async function recomputePaid(tx: Tx, bookingId: string) {
  const payments = await tx.payment.findMany({ where: { bookingId, status: "PAID" } });
  const net = payments.reduce((sum, p) => sum + (p.kind === "REFUND" ? -p.amountBaisa : p.amountBaisa), 0);
  return tx.booking.update({ where: { id: bookingId }, data: { paidBaisa: Math.max(0, net) } });
}

/**
 * After money lands: a booking held as PENDING for its deposit becomes CONFIRMED
 * (when the salon auto-confirms). Returns true when that happened.
 */
async function confirmIfSecured(tx: Tx, bookingId: string, changedById: string | null): Promise<boolean> {
  const b = await tx.booking.findUniqueOrThrow({ where: { id: bookingId }, include: { salon: { select: { autoConfirm: true } } } });
  if (b.status !== "PENDING" || b.paymentRequirement === "NONE" || !b.salon.autoConfirm) return false;
  if (b.paidBaisa < b.depositBaisa) return false;
  const res = await tx.booking.updateMany({ where: { id: b.id, status: "PENDING" }, data: { status: "CONFIRMED" } });
  if (res.count !== 1) return false;
  await tx.bookingStatusHistory.create({
    data: {
      salonId: b.salonId,
      bookingId: b.id,
      kind: "STATUS_CHANGE",
      fromStatus: "PENDING",
      toStatus: "CONFIRMED",
      changedById,
      note: "Payment received",
    },
  });
  return true;
}

export async function recordDeskPayment(input: {
  salonId: string;
  bookingId: string;
  amountBaisa: number;
  method: Exclude<PaymentMethod, "ONLINE">;
  kind: Exclude<PaymentKind, "REFUND">;
  notes?: string | null;
  recordedById: string;
}) {
  const booking = await db.booking.findFirst({ where: { id: input.bookingId, salonId: input.salonId } });
  if (!booking) throw notFound("Booking not found.");
  if (booking.status === "CANCELLED" && input.kind !== "CANCELLATION_FEE") {
    throw badRequest("This booking is cancelled.");
  }
  return db.$transaction(async (tx) => {
    const payment = await tx.payment.create({
      data: {
        salonId: input.salonId,
        bookingId: booking.id,
        customerId: booking.customerId,
        amountBaisa: input.amountBaisa,
        method: input.method,
        kind: input.kind,
        status: "PAID",
        paidAt: new Date(),
        notes: input.notes ?? null,
        recordedById: input.recordedById,
      },
    });
    await recomputePaid(tx, booking.id);
    const confirmed = await confirmIfSecured(tx, booking.id, input.recordedById);
    return { payment, confirmed };
  });
}

/** Customer starts paying online (deposit / full / remaining balance). */
export async function startOnlinePayment(input: { bookingId: string; kind: "DEPOSIT" | "FULL" | "BALANCE" }) {
  const gateway = activeGateway();
  if (!gateway) throw badRequest("Online payment isn't available yet. Please pay at the salon.");
  const booking = await db.booking.findUnique({
    where: { id: input.bookingId },
    include: { salon: { select: { currency: true, name: true } }, service: { select: { name: true } }, customer: true },
  });
  if (!booking) throw notFound("Booking not found.");
  if (!["PENDING", "CONFIRMED", "ARRIVED"].includes(booking.status)) throw badRequest("This booking can't be paid now.");

  const outstanding = booking.priceBaisa - booking.paidBaisa;
  const amount =
    input.kind === "DEPOSIT" ? Math.max(0, booking.depositBaisa - booking.paidBaisa) : outstanding;
  if (amount <= 0) throw conflict("Nothing is due for this booking.");

  // Reuse an open checkout instead of stacking duplicates.
  const open = await db.payment.findFirst({
    where: { bookingId: booking.id, status: "PENDING", method: "ONLINE", amountBaisa: amount },
  });
  if (open) return open;

  const payment = await db.payment.create({
    data: {
      salonId: booking.salonId,
      bookingId: booking.id,
      customerId: booking.customerId,
      amountBaisa: amount,
      method: "ONLINE",
      kind: input.kind === "BALANCE" ? "BALANCE" : input.kind,
      status: "PENDING",
      provider: gateway.name,
    },
  });
  const checkout = await gateway.createCheckout({
    paymentId: payment.id,
    amountBaisa: amount,
    currency: booking.salon.currency,
    description: `${booking.service.name} · ${booking.salon.name} · ${booking.reference}`,
    customerEmail: booking.customer.email,
  });
  return db.payment.update({
    where: { id: payment.id },
    data: { providerRef: checkout.providerRef, checkoutUrl: checkout.checkoutUrl },
  });
}

/** Gateway said "paid" (webhook, or the test gateway's confirm). Idempotent. */
export async function markOnlinePaymentPaid(paymentId: string) {
  return db.$transaction(async (tx) => {
    const res = await tx.payment.updateMany({
      where: { id: paymentId, status: "PENDING" },
      data: { status: "PAID", paidAt: new Date() },
    });
    const payment = await tx.payment.findUniqueOrThrow({ where: { id: paymentId } });
    if (res.count === 0) return { payment, confirmed: false, alreadyProcessed: true };
    await recomputePaid(tx, payment.bookingId);
    const confirmed = await confirmIfSecured(tx, payment.bookingId, null);
    return { payment, confirmed, alreadyProcessed: false };
  });
}

/** Front desk settles an owed refund (cash back / card reversal / transfer). */
export async function settleRefund(input: { salonId: string; paymentId: string; method: PaymentMethod; userId: string }) {
  const p = await db.payment.findFirst({ where: { id: input.paymentId, salonId: input.salonId, kind: "REFUND" } });
  if (!p) throw notFound("Refund not found.");
  if (p.status !== "PENDING") throw badRequest("This refund is already settled.");
  return db.$transaction(async (tx) => {
    const payment = await tx.payment.update({
      where: { id: p.id },
      data: { status: "PAID", paidAt: new Date(), method: input.method, recordedById: input.userId },
    });
    await recomputePaid(tx, p.bookingId);
    return payment;
  });
}

/** Unpaid deposit holds release their slot after this long (cron). */
export const PAYMENT_HOLD_MINUTES = 30;
