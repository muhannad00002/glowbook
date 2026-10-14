import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, notFound } from "@/lib/http";
import { DATE_RE, dateColumn, dateColumnToString } from "@/lib/time";

const minute = z.number().int().min(0).max(1440);

export const eventInput = z.object({
  name: z.string().trim().min(2).max(80),
  nameAr: z.string().trim().max(80).nullable().optional(),
  description: z.string().trim().max(500).nullable().optional(),
  descriptionAr: z.string().trim().max(500).nullable().optional(),
  startDate: z.string().regex(DATE_RE, "Use YYYY-MM-DD."),
  endDate: z.string().regex(DATE_RE, "Use YYYY-MM-DD."),
  openMinute: minute,
  closeMinute: minute,
  isActive: z.boolean().default(true),
});

export const offeringInput = z.object({
  name: z.string().trim().min(2).max(80),
  nameAr: z.string().trim().max(80).nullable().optional(),
  description: z.string().trim().max(500).nullable().optional(),
  tokenMinutes: z.number().int().min(5, "A token is at least 5 minutes.").max(480),
  capacity: z.number().int().min(1).max(50).default(1),
  priceBaisa: z.number().int().min(0).max(10_000_000),
  prepayMode: z.enum(["FULL", "FIXED"]).default("FULL"),
  prepayBaisa: z.number().int().min(0).max(10_000_000).default(0),
  isActive: z.boolean().default(true),
  sortOrder: z.number().int().min(0).max(9999).default(0),
});

export function checkEvent(v: { startDate: string; endDate: string; openMinute: number; closeMinute: number }) {
  if (v.startDate > v.endDate) throw badRequest("The event must end on or after its first day.");
  if (v.openMinute >= v.closeMinute) throw badRequest("Closing time must be after opening time.");
}

/** Customers must pay something up front, and never more than the price. */
export function checkOffering(v: { priceBaisa: number; prepayMode: "FULL" | "FIXED"; prepayBaisa: number }) {
  if (v.prepayMode === "FULL" && v.priceBaisa <= 0) throw badRequest("Set a price — customers pay it in advance.");
  if (v.prepayMode === "FIXED" && v.prepayBaisa <= 0) throw badRequest("Set the advance amount customers pay to book.");
  if (v.prepayMode === "FIXED" && v.prepayBaisa > v.priceBaisa) throw badRequest("The advance can't be more than the price.");
}

export async function ownedEvent(salonId: string, id: string) {
  const e = await db.seasonalEvent.findFirst({ where: { id, salonId } });
  if (!e) throw notFound("Event not found.");
  return e;
}

export async function ownedOffering(salonId: string, id: string) {
  const o = await db.seasonalOffering.findFirst({ where: { id, salonId } });
  if (!o) throw notFound("Offering not found.");
  return o;
}

export function eventView<E extends { startDate: Date; endDate: Date }>(e: E) {
  return { ...e, startDate: dateColumnToString(e.startDate), endDate: dateColumnToString(e.endDate) };
}

export const toDates = (v: { startDate?: string; endDate?: string }) => ({
  ...(v.startDate ? { startDate: dateColumn(v.startDate) } : {}),
  ...(v.endDate ? { endDate: dateColumn(v.endDate) } : {}),
});
