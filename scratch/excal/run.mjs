import http from "node:http"; import fs from "node:fs"; import path from "node:path";
import puppeteer from "puppeteer-core";
const root = path.resolve(".");
const outDir = path.resolve(process.argv[2]);
const types = { ".js": "text/javascript", ".html": "text/html", ".woff2": "font/woff2", ".css": "text/css", ".ttf": "font/ttf", ".json": "application/json" };
const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(new URL(req.url, "http://x").pathname));
  if (!p.startsWith(root) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": types[path.extname(p)] || "application/octet-stream" }); fs.createReadStream(p).pipe(res);
}).listen(0);
const port = server.address().port;
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: true, args: ["--no-first-run", "--no-default-browser-check"] });
const page = await browser.newPage();
page.on("console", m => { if (m.type() === "error" || m.type() === "warning") console.log("page:", m.text()); });
page.on("pageerror", e => console.log("pageerror:", e.message));
await page.goto(`http://localhost:${port}/page.html`);
await page.waitForFunction("window.PAGE_READY && window.EXC_READY", { timeout: 60000 });
const only = process.argv.slice(3);
for (const name of await page.evaluate("window.names()")) {
  if (only.length && !only.includes(name)) continue;
  const r = await page.evaluate((n) => window.build(n), name);
  fs.writeFileSync(path.join(outDir, name + ".svg"), r.svg + "\n");
  const j = JSON.parse(r.json); j.source = "https://excalidraw.com"; fs.writeFileSync(path.join(outDir, name + ".excalidraw"), JSON.stringify(j, null, 2) + "\n");
  console.log("wrote", name, r.svg.length, r.json.length);
}
await browser.close(); server.close();
