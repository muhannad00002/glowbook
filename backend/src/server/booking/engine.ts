import { randomInt } from "node:crypto";
import { db, type Tx } from "@/lib/db";
import { ApiError, conflict, isSlotConflict, notFound, badRequest } from "@/lib/http";
import { localDate } from "@/lib/time";
import type { Booking } from "@/generated/prisma/client";
import type { BookingSource, BookingStatus, PaymentRequirement } from "@/generated/prisma/enums";
import {
  buildDay,
  checkSlot,
  loadAvailabilityData,
  SLOT_PROBLEM_MESSAGES,
  type SalonRules,
  type SlotOptions,
} from "./availability";

/**
 * The booking engine. Two independent layers stop double bookings:
 *  1. Inside a transaction we take a Postgres advisory lock on the staff member, then
 *     re-run the full availability check (hours, leave, blocked time, buffers…). Two
 *     requests for the same artist serialize here; the second sees the first's row.
 *  2. The `booking_no_overlap` exclusion constraint rejects any overlapping live booking
 *     for the same staff member even if application code were bypassed entirely.
 */

export const LIVE_STATUSES: BookingStatus[] = ["PENDING", "CONFIRMED", "ARRIVED", "IN_SERVICE", "COMPLETED"];
const TX_OPTS = { timeout: 15_000, maxWait: 10_000 };

const REF_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export function newReference() {
  let s = "";
  for (let i = 0; i < 6; i++) s += REF_ALPHABET[randomInt(REF_ALPHABET.length)];
  return `GB-${s}`;
}

async function lockStaff(tx: Tx, staffId: string) {
  // Transaction-scoped: released automatically on commit/rollback. Safe through
  // Neon's PgBouncer (transaction pooling) because it never outlives the transaction.
  await tx.$queryRaw`SELECT 1 AS locked FROM (SELECT pg_advisory_xact_lock(hashtextextended(${"staff:" + staffId}, 0))) AS l`;
}

async function salonRules(tx: Tx, salonId: string) {
  const salon = await tx.salon.findUnique({ where: { id: salonId } });
  if (!salon) throw notFound("Salon not found.");
  return salon;
}

async function loadService(tx: Tx, salonId: string, serviceId: string) {
  const service = await tx.service.findFirst({
    where: { id: serviceId, salonId, deletedAt: null },
    include: { staff: { include: { staff: { select: { id: true, isActive: true, sortOrder: true } } } } },
  });
  if (!service || !service.isActive) throw notFound("This service isn't available.");
  const eligible = service.staff
    .filter((s) => s.staff.isActive)
    .sort((a, b) => a.staff.sortOrder - b.staff.sortOrder)
    .map((s) => s.staff.id);
  return { service, eligible };
}

async function verifySlot(
  tx: Tx,
  rules: SalonRules,
  staffId: string,
  start: Date,
  opts: SlotOptions,
  excludeBookingId?: string,
) {
  const date = localDate(start, rules.timezone);
  const data = await loadAvailabilityData(tx, rules, [staffId], date, date, { excludeBookingId });
  return checkSlot(buildDay(data, date), rules, staffId, start, opts);
}

// ---------------------------------------------------------------------------
// Visits (one or more services, back to back, with one artist)
// ---------------------------------------------------------------------------

export const MAX_SERVICES_PER_VISIT = 5;

/**
 * Resolves the services of a visit in the order chosen. The artist must offer every
 * one of them; the visit lasts the sum of their durations, and only the last service's
 * clean-up buffer applies (no tidy-up needed between services for the same client).
 */
export async function loadVisit(tx: Tx, salonId: string, serviceIds: string[]) {
  const ids = [...new Set(serviceIds)];
  if (ids.length === 0) throw badRequest("Choose at least one service.");
  if (ids.length > MAX_SERVICES_PER_VISIT) throw badRequest(`Choose up to ${MAX_SERVICES_PER_VISIT} services per visit.`);
  const loaded = await Promise.all(ids.map((id) => loadService(tx, salonId, id)));
  const eligible = loaded[0].eligible.filter((staffId) => loaded.every((l) => l.eligible.includes(staffId)));
  const services = loaded.map((l) => l.service);
  return {
    services,
    eligible,
    durationMinutes: services.reduce((sum, sv) => sum + sv.durationMinutes, 0),
    bufferMinutes: services[services.length - 1].bufferMinutes,
  };
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

export type CreateBookingInput = {
  salonId: string;
  /** One or more services, performed back to back in this order. */
  serviceIds: string[];
  /** null = "Any available" — the engine picks the least-busy qualified artist. */
  staffId: string | null;
  startTime: Date;
  customerId: string;
  source: BookingSource;
  createdById: string | null;
  customerNotes?: string | null;
  internalNotes?: string | null;
  /** Customer-facing bookings respect min-notice/horizon; the front desk may book "now". */
  enforceNotice: boolean;
  initialStatus?: BookingStatus;
};

function initialStatusFor(
  source: BookingSource,
  requirement: PaymentRequirement,
  autoConfirm: boolean,
  requested?: BookingStatus,
): BookingStatus {
  const customerFacing = source === "CUSTOMER_APP" || source === "PUBLIC_PAGE";
  if (!customerFacing) return requested ?? "CONFIRMED";
  if (requirement !== "NONE") return "PENDING"; // held until the deposit/payment lands
  return autoConfirm ? "CONFIRMED" : "PENDING";
}

/**
 * Books a visit. A multi-service visit becomes consecutive bookings with the same
 * artist sharing a groupId (the first booking's id). They are written in one
 * transaction under the artist's lock, so the whole visit is booked or none of it is.
 */
export async function createBookings(input: CreateBookingInput): Promise<Booking[]> {
  const salon = await salonRules(db, input.salonId);
  const visit = await loadVisit(db, input.salonId, input.serviceIds);
  const customer = await db.customer.findFirst({ where: { id: input.customerId, salonId: input.salonId } });
  if (!customer) throw notFound("Customer not found.");

  const opts: SlotOptions = {
    durationMinutes: visit.durationMinutes,
    bufferMinutes: visit.bufferMinutes,
    now: new Date(),
    enforceNotice: input.enforceNotice,
  };

  let candidates: string[];
  if (input.staffId) {
    if (!visit.eligible.includes(input.staffId)) {
      throw badRequest(
        visit.services.length > 1 ? "This artist doesn't offer all of these services." : "This artist doesn't offer that service.",
      );
    }
    candidates = [input.staffId];
  } else {
    if (visit.eligible.length === 0) throw badRequest("No single artist offers all of these services together.");
    // Rank qualified artists who look free (unlocked read); least-booked that day first.
    const date = localDate(input.startTime, salon.timezone);
    const data = await loadAvailabilityData(db, salon, visit.eligible, date, date);
    const plan = buildDay(data, date);
    const load = (id: string) => data.bookings.filter((b) => b.staffId === id).length;
    candidates = visit.eligible
      .filter((id) => checkSlot(plan, salon, id, input.startTime, opts) === null)
      .sort((a, b) => load(a) - load(b));
    if (candidates.length === 0) throw conflict(SLOT_PROBLEM_MESSAGES.UNAVAILABLE);
  }

  let lastProblem: string = SLOT_PROBLEM_MESSAGES.UNAVAILABLE;
  for (const staffId of candidates) {
    try {
      return await db.$transaction(async (tx) => {
        await lockStaff(tx, staffId);
        const problem = await verifySlot(tx, salon, staffId, input.startTime, opts);
        if (problem) throw new ApiError(409, SLOT_PROBLEM_MESSAGES[problem], { reason: problem });

        const created: Booking[] = [];
        let cursor = input.startTime.getTime();
        for (const [i, service] of visit.services.entries()) {
          const last = i === visit.services.length - 1;
          const requirement = service.paymentRequirement;
          const depositBaisa =
            requirement === "DEPOSIT"
              ? Math.min(service.depositBaisa, service.priceBaisa)
              : requirement === "FULL"
                ? service.priceBaisa
                : 0;
          const status = initialStatusFor(input.source, requirement, salon.autoConfirm, input.initialStatus);
          const startTime = new Date(cursor);
          const endTime = new Date(cursor + service.durationMinutes * 60_000);
          const blockedUntil = new Date(endTime.getTime() + (last ? service.bufferMinutes : 0) * 60_000);
          const booking = await tx.booking.create({
            data: {
              reference: newReference(),
              groupId: created[0]?.id ?? null,
              salonId: salon.id,
              customerId: customer.id,
              staffId,
              serviceId: service.id,
              startTime,
              endTime,
              blockedUntil,
              status,
              source: input.source,
              priceBaisa: service.priceBaisa,
              paymentRequirement: requirement,
              depositBaisa,
              customerNotes: i === 0 ? (input.customerNotes ?? null) : null,
              internalNotes: i === 0 ? (input.internalNotes ?? null) : null,
              createdById: input.createdById,
            },
          });
          await tx.bookingStatusHistory.create({
            data: {
              salonId: salon.id,
              bookingId: booking.id,
              kind: "CREATED",
              toStatus: status,
              newStartTime: booking.startTime,
              newEndTime: booking.endTime,
              newStaffId: staffId,
              changedById: input.createdById,
            },
          });
          created.push(booking);
          cursor = endTime.getTime();
        }
        // The first booking of a multi-service visit anchors the group.
        if (created.length > 1) {
          created[0] = await tx.booking.update({ where: { id: created[0].id }, data: { groupId: created[0].id } });
        }
        return created;
      }, TX_OPTS);
    } catch (e) {
      const retryable = isSlotConflict(e) || (e instanceof ApiError && e.status === 409);
      if (!retryable) throw e;
      if (e instanceof ApiError) lastProblem = e.message;
      // "Any available": someone just took this artist — try the next one.
    }
  }
  throw conflict(lastProblem);
}

/** Single-service convenience (front-desk bookings). */
export async function createBooking(input: Omit<CreateBookingInput, "serviceIds"> & { serviceId: string }): Promise<Booking> {
  const { serviceId, ...rest } = input;
  return (await createBookings({ ...rest, serviceIds: [serviceId] }))[0];
}

// ---------------------------------------------------------------------------
// Reschedule
// ---------------------------------------------------------------------------

const RESCHEDULABLE: BookingStatus[] = ["PENDING", "CONFIRMED"];

export async function rescheduleBooking(input: {
  salonId: string;
  bookingId: string;
  startTime: Date;
  staffId?: string | null;
  changedById: string | null;
  enforceNotice: boolean;
  note?: string | null;
}) {
  const booking = await db.booking.findFirst({ where: { id: input.bookingId, salonId: input.salonId } });
  if (!booking) throw notFound("Booking not found.");
  if (!RESCHEDULABLE.includes(booking.status)) throw badRequest("This booking can no longer be rescheduled.");

  const salon = await salonRules(db, input.salonId);
  const { service, eligible } = await loadService(db, input.salonId, booking.serviceId);
  const staffId = input.staffId ?? booking.staffId;
  if (!eligible.includes(staffId)) throw badRequest("This artist doesn't offer that service.");

  const opts: SlotOptions = {
    durationMinutes: service.durationMinutes,
    bufferMinutes: service.bufferMinutes,
    now: new Date(),
    enforceNotice: input.enforceNotice,
  };
  const endTime = new Date(input.startTime.getTime() + service.durationMinutes * 60_000);
  const blockedUntil = new Date(endTime.getTime() + service.bufferMinutes * 60_000);

  try {
    return await db.$transaction(async (tx) => {
      await lockStaff(tx, staffId);
      const problem = await verifySlot(tx, salon, staffId, input.startTime, opts, booking.id);
      if (problem) throw new ApiError(409, SLOT_PROBLEM_MESSAGES[problem], { reason: problem });

      // Guard against a concurrent status change between our read and this write.
      const moved = await tx.booking.updateMany({
        where: { id: booking.id, status: { in: RESCHEDULABLE }, updatedAt: booking.updatedAt },
        data: { staffId, startTime: input.startTime, endTime, blockedUntil },
      });
      if (moved.count !== 1) throw conflict("This booking was just changed. Please refresh and try again.");

      const history = await tx.bookingStatusHistory.create({
        data: {
          salonId: booking.salonId,
          bookingId: booking.id,
          kind: "RESCHEDULE",
          oldStartTime: booking.startTime,
          oldEndTime: booking.endTime,
          newStartTime: input.startTime,
          newEndTime: endTime,
          oldStaffId: booking.staffId,
          newStaffId: staffId,
          changedById: input.changedById,
          note: input.note ?? null,
        },
      });
      const updated = await tx.booking.findUniqueOrThrow({ where: { id: booking.id } });
      return { booking: updated, historyId: history.id };
    }, TX_OPTS);
  } catch (e) {
    if (isSlotConflict(e)) throw conflict(SLOT_PROBLEM_MESSAGES.UNAVAILABLE);
    throw e;
  }
}

// ---------------------------------------------------------------------------
// Status transitions
// ---------------------------------------------------------------------------

const TRANSITIONS: Record<BookingStatus, BookingStatus[]> = {
  PENDING: ["CONFIRMED", "ARRIVED", "IN_SERVICE", "CANCELLED", "NO_SHOW"],
  CONFIRMED: ["ARRIVED", "IN_SERVICE", "COMPLETED", "CANCELLED", "NO_SHOW", "PENDING"],
  ARRIVED: ["IN_SERVICE", "COMPLETED", "CANCELLED", "CONFIRMED"],
  IN_SERVICE: ["COMPLETED", "ARRIVED"],
  COMPLETED: ["IN_SERVICE"],
  CANCELLED: [],
  NO_SHOW: ["CONFIRMED"],
};

export function canTransition(from: BookingStatus, to: BookingStatus) {
  return TRANSITIONS[from].includes(to);
}

export async function changeStatus(input: {
  salonId: string;
  bookingId: string;
  to: BookingStatus;
  changedById: string | null;
  note?: string | null;
}) {
  if (input.to === "CANCELLED") throw badRequest("Use the cancel endpoint to cancel a booking.");
  const booking = await db.booking.findFirst({ where: { id: input.bookingId, salonId: input.salonId } });
  if (!booking) throw notFound("Booking not found.");
  if (booking.status === input.to) return booking;
  if (!canTransition(booking.status, input.to)) {
    throw badRequest(`A ${booking.status.toLowerCase()} booking can't be marked ${input.to.toLowerCase()}.`);
  }

  try {
    return await db.$transaction(async (tx) => {
      const res = await tx.booking.updateMany({
        where: { id: booking.id, status: booking.status },
        data: {
          status: input.to,
          completedAt: input.to === "COMPLETED" ? new Date() : input.to === "IN_SERVICE" ? null : undefined,
        },
      });
      if (res.count !== 1) throw conflict("This booking was just changed. Please refresh and try again.");
      await tx.bookingStatusHistory.create({
        data: {
          salonId: booking.salonId,
          bookingId: booking.id,
          kind: "STATUS_CHANGE",
          fromStatus: booking.status,
          toStatus: input.to,
          changedById: input.changedById,
          note: input.note ?? null,
        },
      });
      return tx.booking.findUniqueOrThrow({ where: { id: booking.id } });
    }, TX_OPTS);
  } catch (e) {
    // NO_SHOW → CONFIRMED re-occupies the slot; the exclusion constraint may refuse.
    if (isSlotConflict(e)) throw conflict("That time has since been booked by someone else.");
    throw e;
  }
}

// ---------------------------------------------------------------------------
// Cancellation (policy-aware)
// ---------------------------------------------------------------------------

export type CancellationQuote = {
  isFreeCancellation: boolean;
  freeUntil: string;
  paidBaisa: number;
  refundBaisa: number;
  retainedBaisa: number;
  feeBaisa: number;
};

export function quoteCancellation(
  booking: Pick<Booking, "startTime" | "paidBaisa" | "depositBaisa">,
  salon: { cancellationWindowHours: number; lateCancellationFeeBaisa: number; depositPolicy: "REFUNDABLE_IN_WINDOW" | "NON_REFUNDABLE" },
  bySalon: boolean,
  now = new Date(),
): CancellationQuote {
  const freeUntil = new Date(booking.startTime.getTime() - salon.cancellationWindowHours * 3600_000);
  const isFree = bySalon || now <= freeUntil;
  const paid = booking.paidBaisa;
  let retained = 0;
  let fee = 0;
  if (!bySalon) {
    const depositPart = Math.min(paid, booking.depositBaisa);
    if (isFree) {
      retained = salon.depositPolicy === "NON_REFUNDABLE" ? depositPart : 0;
    } else {
      fee = salon.lateCancellationFeeBaisa;
      retained = Math.min(paid, Math.max(depositPart, fee));
    }
  }
  return {
    isFreeCancellation: isFree,
    freeUntil: freeUntil.toISOString(),
    paidBaisa: paid,
    refundBaisa: paid - retained,
    retainedBaisa: retained,
    feeBaisa: fee,
  };
}

const CANCELLABLE: BookingStatus[] = ["PENDING", "CONFIRMED", "ARRIVED"];

export async function cancelBooking(input: {
  salonId: string;
  bookingId: string;
  cancelledById: string | null;
  bySalon: boolean;
  reason?: string | null;
}) {
  const booking = await db.booking.findFirst({ where: { id: input.bookingId, salonId: input.salonId } });
  if (!booking) throw notFound("Booking not found.");
  if (!CANCELLABLE.includes(booking.status)) throw badRequest("This booking can no longer be cancelled.");
  const salon = await salonRules(db, input.salonId);
  const quote = quoteCancellation(booking, salon, input.bySalon);

  return db.$transaction(async (tx) => {
    const res = await tx.booking.updateMany({
      where: { id: booking.id, status: booking.status },
      data: {
        status: "CANCELLED",
        cancelledAt: new Date(),
        cancelledById: input.cancelledById,
        cancelReason: input.reason ?? null,
        cancellationFeeBaisa: quote.feeBaisa,
      },
    });
    if (res.count !== 1) throw conflict("This booking was just changed. Please refresh and try again.");

    // Pending online checkouts for this booking can no longer be paid.
    await tx.payment.updateMany({
      where: { bookingId: booking.id, status: "PENDING", kind: { not: "REFUND" } },
      data: { status: "CANCELLED" },
    });
    if (quote.refundBaisa > 0) {
      // Recorded as owed; the front desk (or the gateway) settles it — see payments.
      await tx.payment.create({
        data: {
          salonId: booking.salonId,
          bookingId: booking.id,
          customerId: booking.customerId,
          amountBaisa: quote.refundBaisa,
          method: "CASH",
          kind: "REFUND",
          status: "PENDING",
          notes: input.bySalon ? "Cancelled by salon" : "Cancelled by customer",
        },
      });
    }
    await tx.bookingStatusHistory.create({
      data: {
        salonId: booking.salonId,
        bookingId: booking.id,
        kind: "STATUS_CHANGE",
        fromStatus: booking.status,
        toStatus: "CANCELLED",
        changedById: input.cancelledById,
        note: input.reason ?? null,
      },
    });
    const updated = await tx.booking.findUniqueOrThrow({ where: { id: booking.id } });
    return { booking: updated, quote };
  }, TX_OPTS);
}

/** Undo a cancellation made moments ago (the "Undo" snackbar). Re-checks the slot. */
export async function restoreBooking(input: { salonId: string; bookingId: string; changedById: string | null }) {
  const booking = await db.booking.findFirst({ where: { id: input.bookingId, salonId: input.salonId } });
  if (!booking) throw notFound("Booking not found.");
  if (booking.status !== "CANCELLED" || !booking.cancelledAt) throw badRequest("Only cancelled bookings can be restored.");
  if (Date.now() - booking.cancelledAt.getTime() > 15 * 60_000) throw badRequest("It's too late to undo this cancellation.");

  const last = await db.bookingStatusHistory.findFirst({
    where: { bookingId: booking.id, toStatus: "CANCELLED" },
    orderBy: { createdAt: "desc" },
  });
  const back: BookingStatus = last?.fromStatus && last.fromStatus !== "CANCELLED" ? last.fromStatus : "CONFIRMED";

  try {
    return await db.$transaction(async (tx) => {
      await lockStaff(tx, booking.staffId);
      await tx.booking.update({
        where: { id: booking.id },
        data: { status: back, cancelledAt: null, cancelReason: null, cancelledById: null, cancellationFeeBaisa: 0 },
      });
      await tx.payment.updateMany({
        where: { bookingId: booking.id, kind: "REFUND", status: "PENDING" },
        data: { status: "CANCELLED", notes: "Cancellation undone" },
      });
      await tx.bookingStatusHistory.create({
        data: {
          salonId: booking.salonId,
          bookingId: booking.id,
          kind: "STATUS_CHANGE",
          fromStatus: "CANCELLED",
          toStatus: back,
          changedById: input.changedById,
          note: "Cancellation undone",
        },
      });
      return tx.booking.findUniqueOrThrow({ where: { id: booking.id } });
    }, TX_OPTS);
  } catch (e) {
    if (isSlotConflict(e)) throw conflict("That time has since been booked by someone else.");
    throw e;
  }
}
