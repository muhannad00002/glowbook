import { db } from "@/lib/db";
import type { TokenPair } from "@/lib/auth/tokens";

export type HomeRole = "SUPER_ADMIN" | "SALON_ADMIN" | "STAFF" | "CUSTOMER";

/** Profile + memberships + which home screen the app should route to. */
export async function buildMe(userId: string) {
  const user = await db.user.findUniqueOrThrow({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      avatarUrl: true,
      locale: true,
      isSuperAdmin: true,
      createdAt: true,
      memberships: {
        where: { isActive: true },
        orderBy: { createdAt: "asc" },
        select: {
          role: true,
          salon: { select: { id: true, name: true, nameAr: true, slug: true, logoUrl: true, timezone: true } },
        },
      },
      staffProfile: { select: { id: true, salonId: true } },
    },
  });

  const memberships = user.memberships.map((m) => ({
    salonId: m.salon.id,
    salonName: m.salon.name,
    salonNameAr: m.salon.nameAr,
    slug: m.salon.slug,
    logoUrl: m.salon.logoUrl,
    timezone: m.salon.timezone,
    role: m.role,
    staffId: user.staffProfile?.salonId === m.salon.id ? user.staffProfile.id : null,
  }));

  let homeRole: HomeRole = "CUSTOMER";
  if (user.isSuperAdmin) homeRole = "SUPER_ADMIN";
  else if (memberships.some((m) => m.role !== "STAFF")) homeRole = "SALON_ADMIN";
  else if (memberships.length > 0) homeRole = "STAFF";

  const { memberships: _m, staffProfile: _s, ...profile } = user;
  return { user: profile, memberships, homeRole };
}

export async function authPayload(userId: string, tokens: TokenPair) {
  return { ...tokens, me: await buildMe(userId) };
}
