import { z } from "zod";
import { db } from "@/lib/db";
import { ok, parseBody, route } from "@/lib/http";
import { emailSchema, hashPassword, passwordSchema, phoneSchema } from "@/lib/auth/password";
import { issueSession } from "@/lib/auth/tokens";
import { authPayload } from "@/server/me";
import { assertEmailFree, assertPhoneFree, createSalonForOwner } from "@/server/auth-service";
import { audit } from "@/server/audit";

const schema = z.object({
  ownerName: z.string().trim().min(2).max(80),
  email: emailSchema,
  password: passwordSchema,
  phone: phoneSchema.optional(),
  salonName: z.string().trim().min(2, "Please enter your salon's name.").max(80),
  city: z.string().trim().max(60).optional(),
  category: z.enum(["MAKEUP", "BEAUTY", "HAIR", "STUDIO", "ARTIST"]).default("MAKEUP"),
  locale: z.enum(["en", "ar"]).default("en"),
});

/** Salon owner sign-up: account + salon + OWNER membership in one step. */
export const POST = route(async (req) => {
  const body = await parseBody(req, schema);
  await assertEmailFree(body.email);
  if (body.phone) await assertPhoneFree(body.phone);
  const user = await db.user.create({
    data: {
      name: body.ownerName,
      email: body.email,
      phone: body.phone ?? null,
      locale: body.locale,
      passwordHash: await hashPassword(body.password),
    },
  });
  const salon = await createSalonForOwner({
    ownerId: user.id,
    salonName: body.salonName,
    phone: body.phone,
    city: body.city,
    category: body.category,
  });
  await audit({ req, salonId: salon.id, userId: user.id, action: "salon.created", entityType: "Salon", entityId: salon.id });
  const tokens = await issueSession(user.id, req.headers.get("user-agent"));
  return ok(await authPayload(user.id, tokens), "Your salon is ready ✨", 201);
});
