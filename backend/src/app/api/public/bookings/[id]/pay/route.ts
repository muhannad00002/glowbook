import { route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { handleCustomerPay } from "@/server/booking/customer-routes";

export const POST = route(async (req, { id }) =>
  handleCustomerPay(req, id, { user: await optionalUser(req), token: req.nextUrl.searchParams.get("token") }),
);
