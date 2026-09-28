import { db } from "@/lib/db";
import type { CustomerSource } from "@/generated/prisma/enums";

/**
 * Finds or creates the salon-scoped CRM record for a booking customer.
 *
 * Matching order: the logged-in user's own record → the phone number → a new record.
 * Linking an account to an existing phone-matched record would expose that record's
 * booking history to the account, so it only happens when the account has *verified*
 * that exact phone number. Otherwise the account gets its own record.
 */
export async function resolveCustomer(input: {
  salonId: string;
  userId?: string | null;
  /** The account's phone, only if verified via OTP. */
  verifiedPhone?: string | null;
  name: string;
  phone?: string | null;
  email?: string | null;
  source: CustomerSource;
}) {
  const { salonId } = input;

  if (input.userId) {
    const linked = await db.customer.findUnique({ where: { salonId_userId: { salonId, userId: input.userId } } });
    if (linked) return linked;
  }

  const byPhone = input.phone
    ? await db.customer.findUnique({ where: { salonId_phone: { salonId, phone: input.phone } } })
    : null;

  if (byPhone) {
    if (!input.userId) return byPhone; // guest / walk-in: same person at the desk
    if (!byPhone.userId && input.verifiedPhone === input.phone) {
      return db.customer.update({
        where: { id: byPhone.id },
        data: { userId: input.userId, email: byPhone.email ?? input.email ?? null },
      });
    }
  }

  return db.customer.create({
    data: {
      salonId,
      userId: input.userId ?? null,
      name: input.name,
      // Keep the phone unique per salon: an unverified duplicate is stored without it.
      phone: byPhone ? null : (input.phone ?? null),
      email: input.email ?? null,
      source: input.source,
    },
  });
}
