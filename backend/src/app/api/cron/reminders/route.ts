import { timingSafeEqual } from "node:crypto";
import { route, unauthorized } from "@/lib/http";
import { runScheduledJobs } from "@/server/cron";

export const maxDuration = 60;

function authorized(header: string | null) {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  const expected = Buffer.from(`Bearer ${secret}`);
  const given = Buffer.from(header ?? "");
  return given.length === expected.length && timingSafeEqual(given, expected);
}

/**
 * Scheduled job entry point. Vercel Cron calls it (see vercel.json) and automatically
 * sends `Authorization: Bearer $CRON_SECRET`. Any external scheduler can call it the
 * same way.
 */
export const GET = route(async (req) => {
  if (!authorized(req.headers.get("authorization"))) throw unauthorized("Invalid cron secret.");
  const started = Date.now();
  const result = await runScheduledJobs();
  return { ...result, tookMs: Date.now() - started };
});
