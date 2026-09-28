import type { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { forbidden, unauthorized } from "@/lib/http";
import { verifyAccessToken } from "./tokens";
import type { SalonRole } from "@/generated/prisma/enums";

export type AuthUser = {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  locale: string;
  isSuperAdmin: boolean;
};

export type SalonContext = {
  user: AuthUser;
  salonId: string;
  role: SalonRole;
  /** The caller's own Staff profile in this salon (set for STAFF, may be set for others). */
  staffId: string | null;
  timezone: string;
};

export const ROLES = {
  ADMIN: ["OWNER", "MANAGER"] as SalonRole[],
  FRONT_DESK: ["OWNER", "MANAGER", "RECEPTIONIST"] as SalonRole[],
  ANY: ["OWNER", "MANAGER", "RECEPTIONIST", "STAFF"] as SalonRole[],
};

function bearer(req: NextRequest): string | null {
  const h = req.headers.get("authorization");
  if (!h?.toLowerCase().startsWith("bearer ")) return null;
  return h.slice(7).trim() || null;
}

/**
 * The caller if signed in, null for guests. A token that is present but expired or
 * invalid is a 401 — not a guest — so the app refreshes and retries instead of
 * silently acting anonymously (e.g. booking as a guest while signed in).
 */
export async function optionalUser(req: NextRequest): Promise<AuthUser | null> {
  const token = bearer(req);
  if (!token) return null;
  const userId = await verifyAccessToken(token);
  if (!userId) throw unauthorized("Your session has expired.");
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, email: true, phone: true, locale: true, isSuperAdmin: true, isActive: true },
  });
  if (!user?.isActive) return null;
  const { isActive: _ignored, ...rest } = user;
  return rest;
}

export async function requireUser(req: NextRequest): Promise<AuthUser> {
  const user = await optionalUser(req);
  if (!user) throw unauthorized();
  return user;
}

export async function requireSuperAdmin(req: NextRequest): Promise<AuthUser> {
  const user = await requireUser(req);
  if (!user.isSuperAdmin) throw forbidden();
  return user;
}

/**
 * Resolves which salon the caller is acting in — from the database, never from the
 * request body. A client may *ask* for a salon via `X-Salon-Id` (for owners of several
 * salons), but the membership is verified here; without the header the caller's first
 * active membership is used.
 */
export async function requireSalon(req: NextRequest, roles: SalonRole[] = ROLES.ANY): Promise<SalonContext> {
  const user = await requireUser(req);
  const requested = req.headers.get("x-salon-id");

  const membership = await db.salonMember.findFirst({
    where: { userId: user.id, isActive: true, ...(requested ? { salonId: requested } : {}) },
    orderBy: { createdAt: "asc" },
    select: { salonId: true, role: true, salon: { select: { timezone: true } } },
  });
  if (!membership) throw forbidden("You are not a member of this salon.");
  if (!roles.includes(membership.role)) throw forbidden("Your role can't do this.");

  const staff = await db.staff.findFirst({
    where: { salonId: membership.salonId, userId: user.id },
    select: { id: true },
  });
  if (membership.role === "STAFF" && !staff) throw forbidden("Your staff profile isn't set up yet.");

  return {
    user,
    salonId: membership.salonId,
    role: membership.role,
    staffId: staff?.id ?? null,
    timezone: membership.salon.timezone,
  };
}

export const isStaffOnly = (ctx: SalonContext) => ctx.role === "STAFF";
