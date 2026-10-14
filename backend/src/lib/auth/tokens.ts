import { SignJWT, jwtVerify } from "jose";
import { createHash, randomBytes } from "node:crypto";
import { db } from "@/lib/db";
import { ApiError } from "@/lib/http";

const ACCESS_TTL_SECONDS = 15 * 60;
const REFRESH_TTL_DAYS = 30;

function secret() {
  const s = process.env.AUTH_SECRET;
  if (!s || s.length < 32) throw new Error("AUTH_SECRET must be set (32+ chars)");
  return new TextEncoder().encode(s);
}

export const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");
export const randomToken = (bytes = 32) => randomBytes(bytes).toString("base64url");

export async function signAccessToken(userId: string) {
  return new SignJWT({ typ: "access" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TTL_SECONDS}s`)
    .sign(secret());
}

export async function verifyAccessToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret(), { algorithms: ["HS256"] });
    if (payload.typ !== "access" || !payload.sub) return null;
    return payload.sub;
  } catch {
    return null;
  }
}

/**
 * Signed link for a customer to view/manage her booking (customers have no accounts).
 * The link really ends a day after the visit (checked when it is opened, so a
 * rescheduled visit keeps a working link); the signature itself is a backstop.
 */
export async function signBookingToken(bookingId: string) {
  return new SignJWT({ typ: "booking" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(bookingId)
    .setIssuedAt()
    .setExpirationTime("60d")
    .sign(secret());
}

export async function verifyBookingToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret(), { algorithms: ["HS256"] });
    return payload.typ === "booking" && payload.sub ? payload.sub : null;
  } catch {
    return null;
  }
}

export type TokenPair = { accessToken: string; refreshToken: string; expiresIn: number };

/** Only the salon team signs in — customers book and manage through links, without accounts. */
export async function isTeamUser(userId: string) {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { isActive: true, isSuperAdmin: true, memberships: { where: { isActive: true }, select: { id: true }, take: 1 } },
  });
  return !!user?.isActive && (user.isSuperAdmin || user.memberships.length > 0);
}

export async function issueSession(userId: string, userAgent?: string | null): Promise<TokenPair> {
  if (!(await isTeamUser(userId))) throw new ApiError(403, "Sign-in is for the salon team only.");
  const refreshToken = randomToken();
  await db.session.create({
    data: {
      userId,
      tokenHash: sha256(refreshToken),
      userAgent: userAgent?.slice(0, 250) ?? null,
      expiresAt: new Date(Date.now() + REFRESH_TTL_DAYS * 86400_000),
    },
  });
  return { accessToken: await signAccessToken(userId), refreshToken, expiresIn: ACCESS_TTL_SECONDS };
}

/**
 * Rotating refresh: the presented token is revoked and a new pair issued. Presenting an
 * already-revoked token means it leaked — every session for that user is revoked.
 */
export async function rotateSession(refreshToken: string, userAgent?: string | null): Promise<TokenPair | null> {
  const session = await db.session.findUnique({
    where: { tokenHash: sha256(refreshToken) },
    include: { user: { select: { isActive: true } } },
  });
  if (!session) return null;
  if (session.revokedAt) {
    await db.session.updateMany({ where: { userId: session.userId, revokedAt: null }, data: { revokedAt: new Date() } });
    return null;
  }
  if (session.expiresAt < new Date() || !session.user.isActive) return null;
  const revoked = await db.session.updateMany({
    where: { id: session.id, revokedAt: null },
    data: { revokedAt: new Date(), lastUsedAt: new Date() },
  });
  if (revoked.count !== 1) return null; // lost a race with a parallel refresh
  if (!(await isTeamUser(session.userId))) return null;
  return issueSession(session.userId, userAgent);
}

export async function revokeSession(refreshToken: string) {
  await db.session.updateMany({
    where: { tokenHash: sha256(refreshToken), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

/**
 * Proof that the bearer just verified this phone with a one-time code (booking flow).
 * Short-lived and carries no account access — it only lets a booking use this phone.
 */
export async function signPhoneToken(phone: string) {
  return new SignJWT({ typ: "phone" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(phone)
    .setIssuedAt()
    .setExpirationTime("30m")
    .sign(secret());
}

export async function verifyPhoneToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret(), { algorithms: ["HS256"] });
    return payload.typ === "phone" && payload.sub ? payload.sub : null;
  } catch {
    return null;
  }
}

/** Signed link for a guest to view a seasonal token (sent over WhatsApp). */
export async function signSeasonalToken(tokenId: string) {
  return new SignJWT({ typ: "seasonal" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(tokenId)
    .setIssuedAt()
    .setExpirationTime("60d")
    .sign(secret());
}

export async function verifySeasonalToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret(), { algorithms: ["HS256"] });
    return payload.typ === "seasonal" && payload.sub ? payload.sub : null;
  } catch {
    return null;
  }
}
