import { route, notFound } from "@/lib/http";

/** Glowbook runs a single salon; new salons aren't created from the app. */
export const POST = route(async () => {
  throw notFound("This system runs a single salon.");
});
