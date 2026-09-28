import { db } from "@/lib/db";
import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";

export const DELETE = route(async (req, { salonId }) => {
  const user = await requireUser(req);
  await db.favorite.deleteMany({ where: { userId: user.id, salonId } });
  return { salonId, isFavorite: false };
});
