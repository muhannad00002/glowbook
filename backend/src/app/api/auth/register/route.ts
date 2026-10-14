import { route, notFound } from "@/lib/http";

/** Customers don't have accounts: they book with a verified phone and get a link. */
export const POST = route(async () => {
  throw notFound("Customer accounts aren't available.");
});
