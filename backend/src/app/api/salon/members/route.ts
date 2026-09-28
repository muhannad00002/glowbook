import { z } from "zod";
import { db } from "@/lib/db";
import { conflict, forbidden, ok, parseBody, route } from "@/lib/http";
import { requireSalon, ROLES } from "@/lib/auth/context";
import { emailSchema, hashPassword, passwordSchema } from "@/lib/auth/password";
import { audit } from "@/server/audit";

export const GET = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  return db.salonMember.findMany({
    where: { salonId: ctx.salonId },
    orderBy: { createdAt: "asc" },
    select: {
      id: true,
      role: true,
      isActive: true,
      createdAt: true,
      user: { select: { id: true, name: true, email: true, phone: true, staffProfile: { select: { id: true, salonId: true } } } },
    },
  });
});

const schema = z.object({
  email: emailSchema,
  name: z.string().trim().min(2).max(80),
  role: z.enum(["MANAGER", "RECEPTIONIST", "STAFF"]),
  /** Initial password when the person has no Glowbook account yet. */
  password: passwordSchema.optional(),
  /** Link a STAFF member to an existing staff profile so she sees her own schedule. */
  staffId: z.string().uuid().optional(),
});

/** Adds a team login. Existing accounts are linked; new ones are created. */
export const POST = route(async (req) => {
  const ctx = await requireSalon(req, ROLES.ADMIN);
  const body = await parseBody(req, schema);
  if (body.role === "MANAGER" && ctx.role !== "OWNER") throw forbidden("Only the owner can add managers.");

  let user = await db.user.findUnique({ where: { email: body.email } });
  if (!user) {
    if (!body.password) throw conflict("This person has no account yet — set an initial password.", { needsPassword: true });
    user = await db.user.create({ data: { email: body.email, name: body.name, passwordHash: await hashPassword(body.password) } });
  }

  const existing = await db.salonMember.findUnique({ where: { salonId_userId: { salonId: ctx.salonId, userId: user.id } } });
  if (existing) throw conflict("This person is already on your team.");

  if (body.staffId) {
    const staff = await db.staff.findFirst({ where: { id: body.staffId, salonId: ctx.salonId } });
    if (!staff) throw conflict("Staff profile not found.");
    if (staff.userId && staff.userId !== user.id) throw conflict("That staff profile is already linked to another login.");
    const otherProfile = await db.staff.findUnique({ where: { userId: user.id } });
    if (otherProfile && otherProfile.id !== staff.id) throw conflict("This account is already linked to a staff profile.");
    await db.staff.update({ where: { id: staff.id }, data: { userId: user.id } });
  }

  const member = await db.salonMember.create({ data: { salonId: ctx.salonId, userId: user.id, role: body.role } });
  await audit({ req, salonId: ctx.salonId, userId: ctx.user.id, action: "member.added", entityType: "SalonMember", entityId: member.id, metadata: { role: body.role, email: body.email } });
  return ok(member, "Team member added.", 201);
});
