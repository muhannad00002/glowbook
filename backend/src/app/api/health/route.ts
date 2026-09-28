import { route } from "@/lib/http";
import { db } from "@/lib/db";

export const GET = route(async () => {
  await db.$queryRaw`SELECT 1`;
  return { status: "ok", time: new Date().toISOString() };
});
