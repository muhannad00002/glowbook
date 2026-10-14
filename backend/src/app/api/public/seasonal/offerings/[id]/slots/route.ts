import { z } from "zod";
import { parseQuery, route } from "@/lib/http";
import { DATE_RE } from "@/lib/time";
import { tokenSlots } from "@/server/seasonal/engine";

/** Token times for one day with the seats left: GET …/slots?date=YYYY-MM-DD */
export const GET = route(async (req, { id }) => {
  const q = parseQuery(req, z.object({ date: z.string().regex(DATE_RE, "Use YYYY-MM-DD.") }));
  return { date: q.date, slots: await tokenSlots(id, q.date) };
});
