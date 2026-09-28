import { db } from "@/lib/db";
import { conflict } from "@/lib/http";
import { hashPassword } from "@/lib/auth/password";

/** Default weekly hours for a new salon: Sat–Thu 09:00–21:00, Fri 14:00–22:00. */
export const DEFAULT_SALON_HOURS = [0, 1, 2, 3, 4, 5, 6].map((d) => ({
  dayOfWeek: d,
  openMinute: d === 5 ? 14 * 60 : 9 * 60,
  closeMinute: d === 5 ? 22 * 60 : 21 * 60,
}));

export function slugify(name: string) {
  const base = name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-")
    .slice(0, 48);
  return base || "salon";
}

export async function uniqueSlug(name: string) {
  const base = slugify(name);
  for (let i = 0; i < 50; i++) {
    const slug = i === 0 ? base : `${base}-${i + 1}`;
    if (!(await db.salon.findUnique({ where: { slug }, select: { id: true } }))) return slug;
  }
  return `${base}-${Date.now().toString(36)}`;
}

export async function assertEmailFree(email: string) {
  if (await db.user.findUnique({ where: { email }, select: { id: true } })) {
    throw conflict("An account with this email already exists.");
  }
}

export async function assertPhoneFree(phone: string) {
  if (await db.user.findUnique({ where: { phone }, select: { id: true } })) {
    throw conflict("An account with this phone number already exists.");
  }
}

/** Salon setup: creates the salon, the owner membership and sensible default hours. */
export async function createSalonForOwner(input: {
  ownerId: string;
  salonName: string;
  phone?: string | null;
  city?: string | null;
  category?: "MAKEUP" | "BEAUTY" | "HAIR" | "STUDIO" | "ARTIST";
}) {
  const slug = await uniqueSlug(input.salonName);
  return db.$transaction(async (tx) => {
    const salon = await tx.salon.create({
      data: {
        name: input.salonName,
        slug,
        phone: input.phone ?? null,
        city: input.city ?? null,
        category: input.category ?? "MAKEUP",
        trialEndsAt: new Date(Date.now() + 30 * 86400_000),
        workingHours: { create: DEFAULT_SALON_HOURS },
      },
    });
    await tx.salonMember.create({ data: { salonId: salon.id, userId: input.ownerId, role: "OWNER" } });
    await tx.serviceCategory.createMany({
      data: [
        { salonId: salon.id, name: "Makeup", nameAr: "مكياج", sortOrder: 0 },
        { salonId: salon.id, name: "Hair", nameAr: "شعر", sortOrder: 1 },
      ],
    });
    return salon;
  });
}

export { hashPassword };
