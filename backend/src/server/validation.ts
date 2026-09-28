import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest } from "@/lib/http";
import { phoneSchema } from "@/lib/auth/password";
import { DATE_RE } from "@/lib/time";

/** Shared input rules for catalogue & team entities. */

export const serviceInput = z.object({
  name: z.string().trim().min(2).max(80),
  nameAr: z.string().trim().max(80).nullable().optional(),
  description: z.string().trim().max(1000).nullable().optional(),
  descriptionAr: z.string().trim().max(1000).nullable().optional(),
  categoryId: z.string().uuid().nullable().optional(),
  priceBaisa: z.number().int().min(0).max(100_000_000),
  durationMinutes: z.number().int().min(5).max(12 * 60),
  bufferMinutes: z.number().int().min(0).max(240).default(0),
  imageUrl: z.string().url().max(500).nullable().optional(),
  isActive: z.boolean().default(true),
  paymentRequirement: z.enum(["NONE", "DEPOSIT", "FULL"]).default("NONE"),
  depositBaisa: z.number().int().min(0).max(100_000_000).default(0),
  sortOrder: z.number().int().min(0).max(10_000).default(0),
  /** Which staff members can perform it. */
  staffIds: z.array(z.string().uuid()).max(100).optional(),
});

export function checkDeposit(v: { paymentRequirement?: string; depositBaisa?: number; priceBaisa?: number }) {
  if (v.paymentRequirement === "DEPOSIT") {
    if (!v.depositBaisa || v.depositBaisa <= 0) throw badRequest("Set a deposit amount.");
    if (v.priceBaisa != null && v.depositBaisa > v.priceBaisa) throw badRequest("The deposit can't be more than the price.");
  }
}

export const HEX_COLOR = /^#[0-9A-Fa-f]{6}$/;

export const staffInput = z.object({
  name: z.string().trim().min(2).max(80),
  nameAr: z.string().trim().max(80).nullable().optional(),
  title: z.string().trim().max(80).nullable().optional(),
  titleAr: z.string().trim().max(80).nullable().optional(),
  photoUrl: z.string().url().max(500).nullable().optional(),
  phone: z.string().trim().max(20).nullable().optional(),
  email: z.string().trim().toLowerCase().email().nullable().optional(),
  bio: z.string().trim().max(600).nullable().optional(),
  color: z.string().regex(HEX_COLOR, "Use a colour like #8E4B61.").default("#8E4B61"),
  isActive: z.boolean().default(true),
  sortOrder: z.number().int().min(0).max(10_000).default(0),
  serviceIds: z.array(z.string().uuid()).max(200).optional(),
  /** Weekly shifts; omitted on create = copy the salon's hours. */
  hours: z
    .array(
      z.object({
        dayOfWeek: z.number().int().min(0).max(6),
        startMinute: z.number().int().min(0).max(1439),
        endMinute: z.number().int().min(1).max(1440),
      }),
    )
    .max(21)
    .optional(),
});

export function checkShifts(hours: { dayOfWeek: number; startMinute: number; endMinute: number }[]) {
  for (const h of hours) if (h.endMinute <= h.startMinute) throw badRequest("A shift must end after it starts.");
  for (let d = 0; d < 7; d++) {
    const day = hours.filter((h) => h.dayOfWeek === d).sort((a, b) => a.startMinute - b.startMinute);
    for (let i = 1; i < day.length; i++) {
      if (day[i].startMinute < day[i - 1].endMinute) throw badRequest("Shifts on the same day can't overlap.");
    }
  }
}

/** Every id must belong to this salon — never trust ids from the client. */
export async function assertOwnedIds(model: "staff" | "service" | "serviceCategory", salonId: string, ids: string[]) {
  if (ids.length === 0) return;
  const unique = [...new Set(ids)];
  const where = { id: { in: unique }, salonId };
  const count =
    model === "staff"
      ? await db.staff.count({ where })
      : model === "service"
        ? await db.service.count({ where: { ...where, deletedAt: null } })
        : await db.serviceCategory.count({ where });
  if (count !== unique.length) throw badRequest("Some of the selected items don't belong to this salon.");
}

export const categoryInput = z.object({
  name: z.string().trim().min(1).max(60),
  nameAr: z.string().trim().max(60).nullable().optional(),
  sortOrder: z.number().int().min(0).max(10_000).default(0),
});

export const customerInput = z.object({
  name: z.string().trim().min(2).max(80),
  phone: phoneSchema.nullable().optional(),
  email: z.string().trim().toLowerCase().email().nullable().optional(),
  birthday: z.string().regex(DATE_RE, "Use YYYY-MM-DD.").nullable().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
  preferredStaffId: z.string().uuid().nullable().optional(),
});
