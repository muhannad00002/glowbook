import type { Prisma } from "@/generated/prisma/client";

/**
 * Field selections for API responses. Customer-facing selections deliberately omit
 * `Booking.internalNotes` and `Customer.notes` (private salon notes) — the privacy
 * boundary is enforced here, by construction, not by remembering to delete fields.
 */

export const staffPublicSelect = {
  id: true,
  name: true,
  nameAr: true,
  title: true,
  titleAr: true,
  photoUrl: true,
  bio: true,
  color: true,
} satisfies Prisma.StaffSelect;

export const serviceSelect = {
  id: true,
  categoryId: true,
  name: true,
  nameAr: true,
  description: true,
  descriptionAr: true,
  priceBaisa: true,
  durationMinutes: true,
  bufferMinutes: true,
  imageUrl: true,
  isActive: true,
  paymentRequirement: true,
  depositBaisa: true,
  sortOrder: true,
} satisfies Prisma.ServiceSelect;

export const salonPublicSelect = {
  id: true,
  slug: true,
  name: true,
  nameAr: true,
  tagline: true,
  taglineAr: true,
  description: true,
  descriptionAr: true,
  category: true,
  phone: true,
  whatsapp: true,
  email: true,
  address: true,
  addressAr: true,
  city: true,
  latitude: true,
  longitude: true,
  timezone: true,
  currency: true,
  logoUrl: true,
  coverUrl: true,
  photos: true,
  ratingAvg: true,
  ratingCount: true,
  slotIntervalMinutes: true,
  minNoticeMinutes: true,
  bookingHorizonDays: true,
  cancellationWindowHours: true,
  lateCancellationFeeBaisa: true,
  depositPolicy: true,
  allowCustomerReschedule: true,
} satisfies Prisma.SalonSelect;

export const salonCardSelect = {
  id: true,
  slug: true,
  name: true,
  nameAr: true,
  tagline: true,
  taglineAr: true,
  category: true,
  city: true,
  coverUrl: true,
  logoUrl: true,
  ratingAvg: true,
  ratingCount: true,
} satisfies Prisma.SalonSelect;

/** Booking as the salon team sees it. */
export const bookingSalonSelect = {
  id: true,
  reference: true,
  groupId: true,
  status: true,
  source: true,
  startTime: true,
  endTime: true,
  blockedUntil: true,
  priceBaisa: true,
  paymentRequirement: true,
  depositBaisa: true,
  paidBaisa: true,
  cancellationFeeBaisa: true,
  customerNotes: true,
  internalNotes: true,
  cancelledAt: true,
  cancelReason: true,
  completedAt: true,
  createdAt: true,
  updatedAt: true,
  staffId: true,
  serviceId: true,
  customerId: true,
  staff: { select: { id: true, name: true, nameAr: true, color: true, photoUrl: true } },
  service: { select: { id: true, name: true, nameAr: true, durationMinutes: true, bufferMinutes: true, priceBaisa: true } },
  customer: { select: { id: true, name: true, phone: true, email: true } },
} satisfies Prisma.BookingSelect;

/** Booking as its customer sees it — no internal notes. */
export const bookingCustomerSelect = {
  id: true,
  reference: true,
  groupId: true,
  status: true,
  startTime: true,
  endTime: true,
  priceBaisa: true,
  paymentRequirement: true,
  depositBaisa: true,
  paidBaisa: true,
  cancellationFeeBaisa: true,
  customerNotes: true,
  cancelledAt: true,
  completedAt: true,
  createdAt: true,
  salon: { select: { ...salonCardSelect, timezone: true, phone: true, address: true, addressAr: true, cancellationWindowHours: true, allowCustomerReschedule: true } },
  staff: { select: { id: true, name: true, nameAr: true, photoUrl: true } },
  service: { select: { id: true, name: true, nameAr: true, durationMinutes: true, imageUrl: true } },
  review: { select: { id: true, rating: true, comment: true, createdAt: true } },
  payments: {
    where: { status: { in: ["PENDING", "PAID"] } },
    select: { id: true, amountBaisa: true, kind: true, method: true, status: true, paidAt: true, checkoutUrl: true },
    orderBy: { createdAt: "asc" },
  },
} satisfies Prisma.BookingSelect;

export const customerListSelect = {
  id: true,
  name: true,
  phone: true,
  email: true,
  birthday: true,
  source: true,
  createdAt: true,
  preferredStaffId: true,
} satisfies Prisma.CustomerSelect;

export const reviewPublicSelect = {
  id: true,
  rating: true,
  comment: true,
  reply: true,
  repliedAt: true,
  createdAt: true,
  customer: { select: { name: true } },
  staff: { select: { id: true, name: true, nameAr: true } },
  booking: { select: { service: { select: { name: true, nameAr: true } } } },
} satisfies Prisma.ReviewSelect;

/** "Sarah Al-Balushi" → "Sarah A." for public review lists. */
export function publicName(full: string) {
  const [first, ...rest] = full.trim().split(/\s+/);
  const last = rest.at(-1);
  return last ? `${first} ${last[0]}.` : first;
}
