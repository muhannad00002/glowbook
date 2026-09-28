// Serves build/web with an SPA fallback so deep links (/salon/maison-beauty) work.
// Usage: node tool/serve_web.mjs [port]   (after `flutter build web`)
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "..", "build", "web");
const port = Number(process.argv[2] ?? 8080);
const types = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json",
  ".css": "text/css", ".png": "image/png", ".ico": "image/x-icon", ".svg": "image/svg+xml", ".wasm": "application/wasm",
  ".otf": "font/otf", ".ttf": "font/ttf", ".woff2": "font/woff2", ".frag": "text/plain", ".bin": "application/octet-stream",
};

createServer(async (req, res) => {
  const url = decodeURIComponent((req.url ?? "/").split("?")[0]);
  let file = normalize(join(root, url));
  if (!file.startsWith(root)) { res.writeHead(403).end(); return; }
  try {
    if ((await stat(file)).isDirectory()) file = join(file, "index.html");
  } catch {
    file = join(root, "index.html"); // SPA fallback
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, { "Content-Type": types[extname(file)] ?? "application/octet-stream", "Cache-Control": "no-cache" });
    res.end(body);
  } catch {
    res.writeHead(404).end("Not found");
  }
}).listen(port, () => console.log(`Glowbook web on http://localhost:${port}`));
