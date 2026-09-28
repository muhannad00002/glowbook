import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { emailSchema } from "@/lib/auth/password";
import { randomToken, sha256 } from "@/lib/auth/tokens";
import { sendAccountMessage } from "@/server/notifications/service";

const schema = z.object({ email: emailSchema });

/** Always answers the same way, so it can't be used to discover which emails exist. */
export const POST = route(async (req) => {
  const { email } = await parseBody(req, schema);
  const user = await db.user.findUnique({ where: { email } });
  let devResetToken: string | undefined;

  if (user?.isActive) {
    const recent = await db.passwordResetToken.count({
      where: { userId: user.id, createdAt: { gte: new Date(Date.now() - 15 * 60_000) } },
    });
    if (recent < 3) {
      const token = randomToken();
      await db.passwordResetToken.create({
        data: { userId: user.id, tokenHash: sha256(token), expiresAt: new Date(Date.now() + 3600_000) },
      });
      const base = process.env.APP_BASE_URL ?? "http://localhost:8080";
      await sendAccountMessage({
        type: "PASSWORD_RESET",
        channel: "EMAIL",
        to: email,
        locale: user.locale,
        userId: user.id,
        variables: { link: `${base}/reset-password?token=${token}` },
      });
      // Local development has no email provider: surface the token so the flow is testable.
      if (process.env.NODE_ENV !== "production" && !process.env.RESEND_API_KEY) devResetToken = token;
    }
  }

  return ok(
    devResetToken ? { devResetToken } : null,
    "If an account exists for that email, we've sent a reset link.",
  );
});
