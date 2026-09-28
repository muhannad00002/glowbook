import { PrismaClient, type Prisma } from "@/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// `next build` imports every route module to collect metadata. Building the client at
// module scope would demand DATABASE_URL at build time, so the real client is created
// lazily on first property access instead.
function createClient() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL is not set");
  // Neon's pooled endpoint (PgBouncer, transaction mode) is safe here: every
  // multi-statement unit of work runs inside an explicit transaction.
  const adapter = new PrismaPg({ connectionString, max: Number(process.env.DB_POOL_MAX ?? 5) });
  return new PrismaClient({ adapter });
}

declare global {
  var __glowbookPrisma: PrismaClient | undefined;
}

function getClient(): PrismaClient {
  if (!globalThis.__glowbookPrisma) globalThis.__glowbookPrisma = createClient();
  return globalThis.__glowbookPrisma;
}

export const db = new Proxy({} as PrismaClient, {
  get(_target, prop) {
    const client = getClient();
    const value = Reflect.get(client as object, prop);
    return typeof value === "function" ? value.bind(client) : value;
  },
});

export type Db = PrismaClient;
/** A Prisma interactive-transaction client (or the root client — both expose the same model API). */
export type Tx = Prisma.TransactionClient;
