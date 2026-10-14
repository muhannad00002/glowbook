import { z } from "zod";
import { parseQuery, route } from "@/lib/http";
import { loadCustomerToken } from "@/server/seasonal/access";
import { tokenLink } from "@/server/notifications/service";
import { buildTokenPass } from "@/server/seasonal/wallet";

/**
 * "Add to Apple Wallet": GET /api/public/tokens/:id/wallet?token=…&lang=en|ar
 * Returns a signed .pkpass — Safari on iPhone opens it straight into Wallet.
 */
export const GET = route(async (req, { id }) => {
  const q = parseQuery(req, z.object({ token: z.string().optional(), lang: z.enum(["en", "ar"]).default("en") }));
  await loadCustomerToken(id, { token: q.token ?? null });
  const { buffer, fileName } = await buildTokenPass(id, { lang: q.lang, link: await tokenLink(id) });
  return new Response(new Uint8Array(buffer), {
    headers: {
      "Content-Type": "application/vnd.apple.pkpass",
      "Content-Disposition": `attachment; filename="${fileName}"`,
      "Cache-Control": "no-store",
    },
  });
});
