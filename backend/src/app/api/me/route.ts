import { z } from "zod";
import { db } from "@/lib/db";
import { parseBody, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { buildMe } from "@/server/me";

export const GET = route(async (req) => {
  const user = await requireUser(req);
  return buildMe(user.id);
});

const patchSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  locale: z.enum(["en", "ar"]).optional(),
  avatarUrl: z.string().url().max(500).nullable().optional(),
});

export const PATCH = route(async (req) => {
  const user = await requireUser(req);
  const body = await parseBody(req, patchSchema);
  await db.user.update({ where: { id: user.id }, data: body });
  return buildMe(user.id);
});
