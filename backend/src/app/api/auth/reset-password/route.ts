import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, ok, parseBody, route } from "@/lib/http";
import { hashPassword, passwordSchema } from "@/lib/auth/password";
import { sha256 } from "@/lib/auth/tokens";

const schema = z.object({ token: z.string().min(10), password: passwordSchema });

export const POST = route(async (req) => {
  const { token, password } = await parseBody(req, schema);
  const row = await db.passwordResetToken.findUnique({ where: { tokenHash: sha256(token) } });
  if (!row || row.usedAt || row.expiresAt < new Date()) {
    throw badRequest("This reset link is invalid or has expired.");
  }
  const passwordHash = await hashPassword(password);
  await db.$transaction([
    db.passwordResetToken.update({ where: { id: row.id }, data: { usedAt: new Date() } }),
    db.user.update({ where: { id: row.userId }, data: { passwordHash } }),
    // Sign out everywhere: whoever had the old password loses access.
    db.session.updateMany({ where: { userId: row.userId, revokedAt: null }, data: { revokedAt: new Date() } }),
  ]);
  return ok({ reset: true }, "Password updated. Please sign in.");
});
