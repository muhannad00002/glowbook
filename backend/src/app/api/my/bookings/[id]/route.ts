import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { loadCustomerBooking } from "@/server/booking/customer-actions";

export const GET = route(async (req, { id }) => {
  const user = await requireUser(req);
  return (await loadCustomerBooking(id, { user })).booking;
});
