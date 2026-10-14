import { route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { loadCustomerToken } from "@/server/seasonal/access";

/** Token page (WhatsApp link): GET /api/public/tokens/:id?token=… */
export const GET = route(async (req, { id }) =>
  loadCustomerToken(id, { user: await optionalUser(req), token: req.nextUrl.searchParams.get("token") }),
);
