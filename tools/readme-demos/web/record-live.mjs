// Records the round-table scene in real time: the window shows a live, isolated
// 12 Knights demo instance (MOCK mode), so frames are captured as it plays.
//   node record-live.mjs <lang> --rt http://127.0.0.1:3799 --record <casebase record id> --say "<message>"

import { createServer } from "node:http";
import { readFile, mkdir, rm, writeFile } from "node:fs/promises";
import { extname, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { webkit } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const [lang = "en", ...rest] = process.argv.slice(2);
const option = (name, fallback) => {
  const index = rest.indexOf(`--${name}`);
  return index >= 0 ? rest[index + 1] : fallback;
};
const rt = option("rt", "http://127.0.0.1:3799");
const recordId = option("record", "");
const message = option("say", "");
const out = option("out", join(here, "../../../build/readme-demos/web"));

const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".png": "image/png" };
const server = createServer(async (req, res) => {
  try {
    const path = join(here, decodeURIComponent(new URL(req.url, "http://x").pathname));
    res.writeHead(200, { "content-type": types[extname(path)] || "application/octet-stream" });
    res.end(await readFile(path));
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(0, resolve));

const browser = await webkit.launch();
const page = await browser.newPage({ viewport: { width: 840, height: 800 }, deviceScaleFactor: 2 });
page.on("pageerror", (error) => console.log("page error:", error.message));
await page.goto(`http://localhost:${server.address().port}/demo.html?scene=roundtable&lang=${lang}&live=1&rt=${encodeURIComponent(rt + "/")}`);
await page.waitForFunction(() => window.casebaseDemo);
await page.evaluate(() => document.fonts.ready);
let knights;
for (let i = 0; i < 50 && !knights; i++) {
  knights = page.frames().find((frame) => frame.url().startsWith(rt));
  if (!knights) await page.waitForTimeout(200);
}
if (!knights) throw new Error(`round-table frame did not load: ${page.frames().map((f) => f.url()).join(", ")}`);
await knights.waitForLoadState("networkidle");
await page.waitForTimeout(1200);
const duration = await page.evaluate(() => window.casebaseDemo.duration);
const markers = await page.evaluate(() => window.casebaseDemo.markers);
const stageBox = await page.locator(".cb-stage").boundingBox();

const frames = join(out, `roundtable-${lang}-frames`);
await rm(frames, { recursive: true, force: true });
await mkdir(frames, { recursive: true });

let discussed = false;
let typed = false;
const stamps = [];
await page.evaluate(() => window.casebaseDemo.begin());
const started = Date.now();
for (;;) {
  const elapsed = (Date.now() - started) / 1000;
  if (elapsed > duration) break;
  if (!discussed && elapsed >= markers.discussAt) {
    discussed = true;
    // What casebase does: POST /api/casebase/discuss, then select that table in the page.
    const response = await fetch(`${rt}/api/casebase/discuss`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ recordId }),
    }).then((r) => r.json());
    await knights.evaluate((id) => { try { localStorage.setItem("cur", id); } catch {} return typeof select === "function" && select(id); }, response.id);
  }
  if (!typed && elapsed >= markers.typeAt) {
    typed = true;
    knights.locator("#t").pressSequentially(message, { delay: 90 }).then(() => knights.locator("#t").press("Enter"));
  }
  const index = stamps.length;
  stamps.push(elapsed);
  await page.screenshot({ path: join(frames, `f${String(index).padStart(5, "0")}.png`), clip: stageBox });
}

const lines = ["ffconcat version 1.0"];
stamps.forEach((t, i) => {
  lines.push(`file f${String(i).padStart(5, "0")}.png`);
  lines.push(`duration ${((stamps[i + 1] ?? t + 0.05) - t).toFixed(4)}`);
});
lines.push(`file f${String(stamps.length - 1).padStart(5, "0")}.png`);
await writeFile(join(frames, "frames.ffconcat"), lines.join("\n"));
const input = ["-f", "concat", "-safe", "0", "-i", join(frames, "frames.ffconcat")];
const name = join(out, `roundtable-${lang}`);
execFileSync("ffmpeg", ["-loglevel", "error", "-y", ...input, "-vf", "fps=30", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart", `${name}.mp4`]);
execFileSync("ffmpeg", ["-loglevel", "error", "-y", ...input,
  "-vf", "fps=10,scale=840:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle",
  `${name}.gif`]);
// Lossless GIF optimization; lossy modes smear the dark panels.
try { execFileSync("gifsicle", ["-O3", "-b", `${name}.gif`]); } catch { console.log("gifsicle not found; GIF left unoptimized"); }
console.log(`${stamps.length} frames in ${duration.toFixed(1)}s -> ${name}.{gif,mp4}`);

await browser.close();
server.close();
