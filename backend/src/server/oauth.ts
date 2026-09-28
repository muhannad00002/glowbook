import { createRemoteJWKSet, jwtVerify } from "jose";
import { db } from "@/lib/db";
import { ApiError, unauthorized } from "@/lib/http";

/**
 * Social sign-in. The app obtains an ID token from Google / Apple natively and posts
 * it here; we verify its signature against the provider's published keys, check the
 * audience is *our* client id, then sign in / link / create the account.
 */

const PROVIDERS = {
  google: {
    jwks: createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs")),
    issuers: ["https://accounts.google.com", "accounts.google.com"],
    audiencesEnv: "GOOGLE_CLIENT_IDS",
    field: "googleSub" as const,
  },
  apple: {
    jwks: createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys")),
    issuers: ["https://appleid.apple.com"],
    audiencesEnv: "APPLE_CLIENT_IDS",
    field: "appleSub" as const,
  },
};

export async function signInWithIdToken(provider: keyof typeof PROVIDERS, idToken: string, fallbackName?: string) {
  const cfg = PROVIDERS[provider];
  const audiences = (process.env[cfg.audiencesEnv] ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (audiences.length === 0) throw new ApiError(503, `${provider} sign-in isn't configured.`);

  let claims: { sub?: string; email?: string; email_verified?: boolean | string; name?: string };
  try {
    const { payload } = await jwtVerify(idToken, cfg.jwks, { issuer: cfg.issuers, audience: audiences });
    claims = payload as typeof claims;
  } catch {
    throw unauthorized("Sign-in failed. Please try again.");
  }
  if (!claims.sub) throw unauthorized("Sign-in failed. Please try again.");

  const email = claims.email?.toLowerCase();
  const emailVerified = claims.email_verified === true || claims.email_verified === "true";

  const bySub = await db.user.findFirst({ where: { [cfg.field]: claims.sub } });
  if (bySub) return bySub;

  if (email && emailVerified) {
    const byEmail = await db.user.findUnique({ where: { email } });
    if (byEmail) {
      return db.user.update({
        where: { id: byEmail.id },
        data: { [cfg.field]: claims.sub, emailVerifiedAt: byEmail.emailVerifiedAt ?? new Date() },
      });
    }
  }

  return db.user.create({
    data: {
      [cfg.field]: claims.sub,
      email: email && emailVerified ? email : null,
      emailVerifiedAt: email && emailVerified ? new Date() : null,
      name: claims.name ?? fallbackName ?? "Glowbook guest",
    },
  });
}
