// Records the HTML demos frame by frame in WebKit and encodes them.
//   node record.mjs <scene> <lang> [--fps 30] [--stills 1.2,3.4] [--out dir]
// Writes <out>/<scene>-<lang>.gif and .mp4 (or PNG stills when --stills is given).

import { createServer } from "node:http";
import { readFile, mkdir, rm } from "node:fs/promises";
import { extname, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { webkit } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const [scene = "drop", lang = "en", ...rest] = process.argv.slice(2);
const option = (name, fallback) => {
  const index = rest.indexOf(`--${name}`);
  return index >= 0 ? rest[index + 1] : fallback;
};
const fps = Number(option("fps", "30"));
const stills = option("stills", null);
const out = option("out", join(here, "../../../build/readme-demos/web"));
const extra = option("query", "");

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
const port = server.address().port;

const browser = await webkit.launch();
const page = await browser.newPage({ viewport: { width: 840, height: 800 }, deviceScaleFactor: 2 });
page.on("console", (message) => console.log("page:", message.text()));
page.on("pageerror", (error) => console.log("page error:", error.message));
await page.goto(`http://localhost:${port}/demo.html?scene=${scene}&lang=${lang}&record=1${extra ? "&" + extra : ""}`);
await page.waitForFunction(() => window.casebaseDemo);
await page.evaluate(() => document.fonts.ready);
const duration = await page.evaluate(() => window.casebaseDemo.duration);
const stageBox = await page.locator(".cb-stage").boundingBox();

await mkdir(out, { recursive: true });
const name = `${scene}-${lang}${extra ? "-" + extra.replace(/[^a-z0-9]+/gi, "_") : ""}`;

async function shoot(t, path) {
  await page.evaluate((time) => window.casebaseDemo.seek(time), t);
  await page.screenshot({ path, clip: stageBox });
}

if (stills) {
  for (const t of stills.split(",").map(Number)) {
    await shoot(t, join(out, `${name}-${t.toFixed(2)}.png`));
  }
} else {
  const frames = join(out, `${name}-frames`);
  await rm(frames, { recursive: true, force: true });
  await mkdir(frames, { recursive: true });
  const count = Math.ceil(duration * fps);
  for (let i = 0; i < count; i++) {
    await shoot(i / fps, join(frames, `f${String(i).padStart(5, "0")}.png`));
  }
  const input = ["-framerate", String(fps), "-i", join(frames, "f%05d.png")];
  execFileSync("ffmpeg", ["-loglevel", "error", "-y", ...input,
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart", join(out, `${name}.mp4`)]);
  execFileSync("ffmpeg", ["-loglevel", "error", "-y", ...input,
    "-vf", "fps=20,scale=840:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=200:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle",
    join(out, `${name}.gif`)]);
  console.log(`${count} frames, ${duration.toFixed(1)}s -> ${join(out, name)}.{gif,mp4}`);
}

await browser.close();
server.close();
