import { NextResponse, type NextRequest } from "next/server";
import { z, ZodError, type ZodType } from "zod";

/**
 * Every response uses one envelope:
 *   { success: true,  data: <payload>, message: string | null }
 *   { success: false, data: <details> | null, message: "Human readable reason" }
 */
export type Envelope<T> = { success: boolean; data: T | null; message: string | null };

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public data: unknown = null,
  ) {
    super(message);
  }
}

export const badRequest = (m: string, data?: unknown) => new ApiError(400, m, data);
export const unauthorized = (m = "Please sign in to continue.") => new ApiError(401, m);
export const forbidden = (m = "You don't have access to this.") => new ApiError(403, m);
export const notFound = (m = "Not found.") => new ApiError(404, m);
export const conflict = (m: string, data?: unknown) => new ApiError(409, m, data);
export const gone = (m: string) => new ApiError(410, m, { expired: true });

/** A customer's link keeps working until a day after her appointment ends. */
export const LINK_GRACE_MS = 24 * 3600_000;

export function ok<T>(data: T, message: string | null = null, status = 200) {
  return NextResponse.json<Envelope<T>>({ success: true, data, message }, { status });
}

export function fail(status: number, message: string, data: unknown = null) {
  return NextResponse.json<Envelope<unknown>>({ success: false, data, message }, { status });
}

/** Postgres exclusion-constraint violation = someone else just took the slot. */
export function isSlotConflict(e: unknown): boolean {
  const text = JSON.stringify(e, Object.getOwnPropertyNames(e ?? {})) + String(e);
  return text.includes("23P01") || text.includes("booking_no_overlap");
}

function isUniqueViolation(e: unknown): boolean {
  const code = (e as { code?: string })?.code;
  const text = String((e as Error)?.message ?? "");
  return code === "P2002" || text.includes("Unique constraint");
}

export function toErrorResponse(e: unknown) {
  if (e instanceof ApiError) return fail(e.status, e.message, e.data);
  if (e instanceof ZodError) {
    const fields: Record<string, string> = {};
    for (const issue of e.issues) {
      const key = issue.path.join(".") || "_";
      if (!fields[key]) fields[key] = issue.message;
    }
    const first = e.issues[0];
    const where = first?.path.length ? `${first.path.join(".")}: ` : "";
    return fail(422, `${where}${first?.message ?? "Invalid input."}`, { fields });
  }
  if (isSlotConflict(e)) return fail(409, "Appointment is no longer available.");
  if (isUniqueViolation(e)) return fail(409, "That already exists.");
  if ((e as { code?: string })?.code === "P2025") return fail(404, "Not found.");
  console.error("[api] unhandled error", e);
  return fail(500, "Something went wrong. Please try again.");
}

type RouteContext = { params: Promise<Record<string, string>> };
type Handler<T> = (req: NextRequest, params: Record<string, string>) => Promise<T | Response>;

/** Wraps a route handler with the response envelope and uniform error mapping. */
export function route<T>(fn: Handler<T>) {
  return async (req: NextRequest, ctx: RouteContext) => {
    try {
      const params = (await ctx?.params) ?? {};
      const result = await fn(req, params);
      if (result instanceof Response) return result;
      return ok(result ?? null);
    } catch (e) {
      return toErrorResponse(e);
    }
  };
}

export async function parseBody<S extends ZodType>(req: NextRequest, schema: S): Promise<z.infer<S>> {
  let json: unknown;
  try {
    json = await req.json();
  } catch {
    throw badRequest("Request body must be valid JSON.");
  }
  return schema.parse(json);
}

/**
 * For PATCH: validates against `schema.partial()` but keeps only keys the client
 * actually sent. (Zod 4's `.partial()` still applies `.default()`s, which would silently
 * reset untouched fields like `isActive` or `sortOrder`.)
 */
export async function parsePatch<S extends z.ZodObject>(req: NextRequest, schema: S): Promise<Partial<z.infer<S>>> {
  let json: unknown;
  try {
    json = await req.json();
  } catch {
    throw badRequest("Request body must be valid JSON.");
  }
  if (typeof json !== "object" || json === null || Array.isArray(json)) throw badRequest("Expected a JSON object.");
  const parsed = schema.partial().parse(json) as Record<string, unknown>;
  const sent = new Set(Object.keys(json));
  for (const k of Object.keys(parsed)) if (!sent.has(k)) delete parsed[k];
  return parsed as Partial<z.infer<S>>;
}

export function parseQuery<S extends ZodType>(req: NextRequest, schema: S): z.infer<S> {
  const raw: Record<string, string> = {};
  req.nextUrl.searchParams.forEach((v, k) => {
    raw[k] = v;
  });
  return schema.parse(raw);
}

export function clientIp(req: NextRequest): string | null {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? req.headers.get("x-real-ip");
}
