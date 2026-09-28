// Local Postgres for development/testing without a Neon database.
// Runs a real PostgreSQL server (same engine as Neon, incl. btree_gist) on :5433.
// Usage: node scripts/local-db.mjs   → then DATABASE_URL=postgresql://glowbook:glowbook@localhost:5433/glowbook
import EmbeddedPostgres from "embedded-postgres";
import { existsSync } from "node:fs";

const dataDir = new URL("../.localdb", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");
const pg = new EmbeddedPostgres({
  databaseDir: dataDir,
  user: "glowbook",
  password: "glowbook",
  port: 5433,
  persistent: true,
  postgresFlags: ["-c", "timezone=UTC"],
});

const fresh = !existsSync(`${dataDir}/PG_VERSION`);
if (fresh) await pg.initialise();
await pg.start();
if (fresh) await pg.createDatabase("glowbook");
console.log("Local Postgres ready on postgresql://glowbook:glowbook@localhost:5433/glowbook");

const stop = async () => { await pg.stop(); process.exit(0); };
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
