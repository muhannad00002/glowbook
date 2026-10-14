import { db } from "@/lib/db";
import { ApiError, forbidden, notFound } from "@/lib/http";
import type { AuthUser } from "@/lib/auth/context";
import { verifyPhoneToken, verifySeasonalToken } from "@/lib/auth/tokens";
import { salonCardSelect } from "@/server/dto";
import { prepayFor } from "./engine";

/**
 * The phone a customer has proven they own: a phone token from the one-time-code step,
 * or a signed-in account's verified phone. Throws unless it is `phone`.
 */
export async function requireVerifiedPhone(user: AuthUser | null, phone: string, phoneToken?: string) {
  const account = user
    ? await db.user.findUnique({ where: { id: user.id }, select: { phone: true, phoneVerifiedAt: true } })
    : null;
  let verified = account?.phoneVerifiedAt ? account.phone : null;
  if (phoneToken) {
    const fromToken = await verifyPhoneToken(phoneToken);
    if (!fromToken) throw new ApiError(401, "Your verification has expired. Please verify your phone again.", { needsVerification: true });
    verified = fromToken;
  }
  if (verified !== phone) throw new ApiError(403, "Please verify your phone number to continue.", { needsVerification: true });
  return verified;
}

export const tokenCustomerSelect = {
  id: true,
  reference: true,
  number: true,
  date: true,
  startTime: true,
  endTime: true,
  status: true,
  priceBaisa: true,
  prepayBaisa: true,
  paidBaisa: true,
  holdExpiresAt: true,
  paidAt: true,
  customerNotes: true,
  arrivedAt: true,
  completedAt: true,
  cancelledAt: true,
  createdAt: true,
  offering: {
    select: {
      id: true,
      name: true,
      nameAr: true,
      tokenMinutes: true,
      event: { select: { id: true, name: true, nameAr: true } },
    },
  },
  salon: { select: { ...salonCardSelect, timezone: true, phone: true, address: true, addressAr: true } },
} as const;

/** The token as its customer sees it: the signed-in owner, or a guest with the link token. */
export async function loadCustomerToken(id: string, who: { user?: AuthUser | null; token?: string | null }) {
  const row = await db.seasonalToken.findUnique({
    where: { id },
    select: { ...tokenCustomerSelect, customer: { select: { userId: true, name: true, phone: true } } },
  });
  if (!row) throw notFound("Token not found.");
  const ownerOk = !!who.user && row.customer.userId === who.user.id;
  const tokenOk = !!who.token && (await verifySeasonalToken(who.token)) === id;
  if (!ownerOk && !tokenOk) throw forbidden("You can't view this token.");
  const { customer, ...token } = row;
  const holdActive = token.status === "PENDING_PAYMENT" && !!token.holdExpiresAt && token.holdExpiresAt > new Date();
  return {
    ...token,
    // A lapsed hold reads as expired even before the cron sweeps it.
    status: token.status === "PENDING_PAYMENT" && !holdActive ? "EXPIRED" : token.status,
    customer: { name: customer.name, phone: customer.phone },
    dueBaisa: holdActive ? Math.max(0, token.prepayBaisa - token.paidBaisa) : 0,
    balanceBaisa: Math.max(0, token.priceBaisa - token.paidBaisa),
  };
}

/** An offering as the public sees it. */
export function publicOffering(o: {
  id: string;
  name: string;
  nameAr: string | null;
  description: string | null;
  tokenMinutes: number;
  capacity: number;
  priceBaisa: number;
  prepayMode: "FULL" | "FIXED";
  prepayBaisa: number;
}) {
  return {
    id: o.id,
    name: o.name,
    nameAr: o.nameAr,
    description: o.description,
    tokenMinutes: o.tokenMinutes,
    capacity: o.capacity,
    priceBaisa: o.priceBaisa,
    prepayMode: o.prepayMode,
    prepayBaisa: prepayFor(o),
  };
}
