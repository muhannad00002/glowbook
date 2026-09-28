import { NextResponse, type NextRequest } from "next/server";

/**
 * CORS for the Flutter web app (a different origin from the API). Auth is a bearer
 * token, not a cookie, so no credentials mode is needed. Allowed origins come from
 * CORS_ORIGINS (comma-separated); any localhost port is allowed outside production.
 */
function allowedOrigin(origin: string | null): string | null {
  if (!origin) return null;
  const list = (process.env.CORS_ORIGINS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (list.includes("*") || list.includes(origin)) return origin;
  if (process.env.NODE_ENV !== "production" && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return origin;
  return null;
}

export function proxy(req: NextRequest) {
  const origin = allowedOrigin(req.headers.get("origin"));
  const headers: Record<string, string> = origin
    ? {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
        "Access-Control-Allow-Headers": "Authorization,Content-Type,X-Salon-Id,Accept-Language",
        "Access-Control-Max-Age": "86400",
        Vary: "Origin",
      }
    : {};

  if (req.method === "OPTIONS") return new NextResponse(null, { status: 204, headers });
  const res = NextResponse.next();
  for (const [k, v] of Object.entries(headers)) res.headers.set(k, v);
  return res;
}

export const config = { matcher: "/api/:path*" };
