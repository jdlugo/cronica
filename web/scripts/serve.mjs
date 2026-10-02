import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";

const root = normalize(join(import.meta.dirname, ".."));
const port = Number(process.env.PORT || 4173);
const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
};

createServer((request, response) => {
  const pathname = new URL(request.url, `http://${request.headers.host}`).pathname;
  const relative = pathname === "/" ? "index.html" : pathname.replace(/^\//, "");
  const candidates = [normalize(join(root, relative)), normalize(join(root, "public", relative))];
  let path = candidates.find((candidate) => (
    candidate.startsWith(root) && existsSync(candidate) && !statSync(candidate).isDirectory()
  ));
  if (!path) path = join(root, "index.html");
  response.setHeader("Content-Type", types[extname(path)] || "application/octet-stream");
  response.setHeader("Cache-Control", "no-store");
  createReadStream(path).pipe(response);
}).listen(port, "127.0.0.1", () => {
  process.stdout.write(`Daily Reel preview: http://127.0.0.1:${port}\n`);
});
