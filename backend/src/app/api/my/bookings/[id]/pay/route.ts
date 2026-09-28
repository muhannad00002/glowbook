import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { handleCustomerPay } from "@/server/booking/customer-routes";

export const POST = route(async (req, { id }) => handleCustomerPay(req, id, { user: await requireUser(req), token: null }));
