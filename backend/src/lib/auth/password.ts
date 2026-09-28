import bcrypt from "bcryptjs";
import { z } from "zod";

export const hashPassword = (plain: string) => bcrypt.hash(plain, 11);
export const verifyPassword = (plain: string, hash: string) => bcrypt.compare(plain, hash);

export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters.")
  .max(128, "Password is too long.");

/** E.164-ish: optional +, 8–15 digits. Spaces/dashes are stripped first. */
export const phoneSchema = z
  .string()
  .transform((v) => v.replace(/[\s\-()]/g, ""))
  .pipe(z.string().regex(/^\+?\d{8,15}$/, "Enter a valid phone number."));

export const emailSchema = z.string().trim().toLowerCase().email("Enter a valid email address.");
