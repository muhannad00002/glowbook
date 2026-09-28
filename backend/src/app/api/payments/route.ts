import { z } from "zod";
import { db } from "@/lib/db";
import { parseQuery, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { DATE_RE, dayRange } from "@/lib/time";
import type { Prisma } from "@/generated/prisma/client";

const schema = z.object({
  from: z.string().regex(DATE_RE).optional(),
  to: z.string().regex(DATE_RE).optional(),
  status: z.enum(["PENDING", "PAID", "FAILED", "REFUNDED", "CANCELLED"]).optional(),
  kind: z.enum(["DEPOSIT", "BALANCE", "FULL", "CANCELLATION_FEE", "REFUND"]).optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

/** Payments ledger for the salon, plus totals for the selected range. */
export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.FRONT_DESK);
  const q = parseQuery(req, schema);
  const where: Prisma.PaymentWhereInput = { salonId: ctx.salonId };
  if (q.from || q.to) {
    where.createdAt = {
      ...(q.from ? { gte: dayRange(q.from, ctx.timezone).start } : {}),
      ...(q.to ? { lt: dayRange(q.to, ctx.timezone).end } : {}),
    };
  }
  if (q.status) where.status = q.status;
  if (q.kind) where.kind = q.kind;

  const rows = await db.payment.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: q.limit,
    include: {
      booking: { select: { id: true, reference: true, startTime: true, service: { select: { name: true } } } },
      customer: { select: { id: true, name: true } },
    },
  });
  const paid = rows.filter((p) => p.status === "PAID");
  const collected = paid.filter((p) => p.kind !== "REFUND").reduce((s, p) => s + p.amountBaisa, 0);
  const refunded = paid.filter((p) => p.kind === "REFUND").reduce((s, p) => s + p.amountBaisa, 0);
  const owedRefunds = rows.filter((p) => p.kind === "REFUND" && p.status === "PENDING").reduce((s, p) => s + p.amountBaisa, 0);
  const byMethod: Record<string, number> = {};
  for (const p of paid) if (p.kind !== "REFUND") byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amountBaisa;

  return { items: rows, totals: { collectedBaisa: collected, refundedBaisa: refunded, netBaisa: collected - refunded, owedRefundsBaisa: owedRefunds, byMethod } };
});
