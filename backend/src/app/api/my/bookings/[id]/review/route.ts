import { z } from "zod";
import { db } from "@/lib/db";
import { badRequest, conflict, ok, parseBody, route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { loadCustomerBooking } from "@/server/booking/customer-actions";
import { refreshSalonRating } from "@/server/reviews";

const schema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(1000).optional(),
});

export const POST = route(async (req, { id }) => {
  const user = await requireUser(req);
  const body = await parseBody(req, schema);
  const { booking, salonId } = await loadCustomerBooking(id, { user });
  if (booking.status !== "COMPLETED") throw badRequest("You can review an appointment once it's completed.");
  if (booking.review) throw conflict("You've already reviewed this appointment.");
  const full = await db.booking.findUniqueOrThrow({ where: { id }, select: { customerId: true, staffId: true } });
  const review = await db.review.create({
    data: {
      salonId,
      bookingId: id,
      customerId: full.customerId,
      userId: user.id,
      staffId: full.staffId,
      rating: body.rating,
      comment: body.comment || null,
    },
  });
  await refreshSalonRating(salonId);
  return ok(review, "Thank you for your review 💕", 201);
});
