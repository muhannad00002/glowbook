import { route } from "@/lib/http";
import { requireUser } from "@/lib/auth/context";
import { handleCustomerCancel } from "@/server/booking/customer-routes";

export const POST = route(async (req, { id }) => handleCustomerCancel(req, id, { user: await requireUser(req), token: null }));
