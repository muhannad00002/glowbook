import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { emailSchema, hashPassword, passwordSchema, phoneSchema } from "@/lib/auth/password";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";
import { assertEmailFree, assertPhoneFree } from "@/server/auth-service";

const schema = z.object({
  name: z.string().trim().min(2, "Please enter your name.").max(80),
  email: emailSchema,
  password: passwordSchema,
  phone: phoneSchema.optional(),
  locale: z.enum(["en", "ar"]).default("en"),
});

/** Customer self-registration. */
export const POST = route(async (req) => {
  const body = await parseBody(req, schema);
  await assertEmailFree(body.email);
  if (body.phone) await assertPhoneFree(body.phone);
  const user = await db.user.create({
    data: {
      name: body.name,
      email: body.email,
      phone: body.phone ?? null,
      locale: body.locale,
      passwordHash: await hashPassword(body.password),
    },
  });
  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return ok(await authPayload(user.id, tokens), "Welcome to Glowbook ✨", 201);
});
