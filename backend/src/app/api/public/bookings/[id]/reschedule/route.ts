import { route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { handleCustomerReschedule } from "@/server/booking/customer-routes";

export const POST = route(async (req, { id }) =>
  handleCustomerReschedule(req, id, { user: await optionalUser(req), token: req.nextUrl.searchParams.get("token") }),
);
