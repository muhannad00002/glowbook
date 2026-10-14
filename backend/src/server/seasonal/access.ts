import { db } from "@/lib/db";
import { ApiError, forbidden, gone, LINK_GRACE_MS, notFound } from "@/lib/http";
import type { AuthUser } from "@/lib/auth/context";
import { verifyPhoneToken, verifySeasonalToken } from "@/lib/auth/tokens";
import { salonCardSelect } from "@/server/dto";
import { prepayFor } from "./engine";

/** The phone a customer has just proven she owns (one-time-code token). Throws unless it is `phone`. */
export async function requireVerifiedPhone(phone: string, phoneToken?: string) {
  const verified = phoneToken ? await verifyPhoneToken(phoneToken) : null;
  if (phoneToken && !verified) throw new ApiError(401, "Your verification has expired. Please verify your phone again.", { needsVerification: true });
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

/** The token as its customer sees it — through the link we sent, until a day after the token. */
export async function loadCustomerToken(id: string, who: { user?: AuthUser | null; token?: string | null }) {
  const row = await db.seasonalToken.findUnique({
    where: { id },
    select: { ...tokenCustomerSelect, customer: { select: { userId: true, name: true, phone: true } } },
  });
  if (!row) throw notFound("Token not found.");
  const tokenOk = !!who.token && (await verifySeasonalToken(who.token)) === id;
  if (!tokenOk) throw forbidden("This link isn't valid. Please use the link we sent you.");
  if (Date.now() > row.endTime.getTime() + LINK_GRACE_MS) throw gone("This link has expired.");
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
