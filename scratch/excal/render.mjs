// Render SVGs as <img> (like GitHub) in headless Chrome: one PNG per diagram + a contact sheet.
import fs from "node:fs"; import path from "node:path"; import puppeteer from "puppeteer-core";
const dir = path.resolve(process.argv[2]); const sheet = path.resolve(process.argv[3]); const single = process.argv[4];
const svgs = fs.readdirSync(dir).filter(f => f.endsWith(".svg")).sort();
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: true });
const page = await browser.newPage();
const uri = f => "data:image/svg+xml;base64," + fs.readFileSync(path.join(dir, f)).toString("base64");
if (single) {
  for (const f of svgs) {
    await page.setViewport({ width: 1600, height: 1000, deviceScaleFactor: 1 });
    await page.setContent(`<body style="margin:0;background:#fff"><img id=i src="${uri(f)}"></body>`);
    await page.waitForFunction("document.getElementById('i').complete"); await new Promise(r => setTimeout(r, 300));
    const el = await page.$("#i"); await el.screenshot({ path: path.join(single, f.replace(".svg", ".png")) });
  }
}
const cells = svgs.map(f => `<figure><img src="${uri(f)}"><figcaption>${f}</figcaption></figure>`).join("");
await page.setViewport({ width: 2000, height: 1000, deviceScaleFactor: 1 });
await page.setContent(`<html><body style="margin:0;padding:16px;background:#d0d7de;font:18px sans-serif">
<div style="display:grid;grid-template-columns:repeat(2,1fr);gap:16px;align-items:start">${cells}</div>
<style>figure{margin:0;background:#fff;padding:8px;border-radius:6px}img{width:100%;display:block}figcaption{padding-top:6px;color:#333}</style></body></html>`);
await page.waitForFunction("[...document.images].every(i => i.complete)"); await new Promise(r => setTimeout(r, 500));
await page.screenshot({ path: sheet, fullPage: true });
await browser.close();
