import { route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { loadCustomerBooking } from "@/server/booking/customer-actions";

/** Guest manage page: GET /api/public/bookings/:id?token=… */
export const GET = route(async (req, { id }) => {
  const token = req.nextUrl.searchParams.get("token");
  const { booking } = await loadCustomerBooking(id, { user: await optionalUser(req), token });
  return booking;
});
