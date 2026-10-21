// casebase.space: the live notch, language switch, demos that play while visible.
import { pixelIconSVG } from "/demos/engine.js";

const EN = {
  "nav.save": "Save",
  "nav.ask": "Ask",
  "nav.ai": "AI tools",
  "nav.download": "Download",
  "hero.title": "Stop asking<br><span class=\"quote\">“where did I put that?”</span>",
  "hero.sub": "Drop it in the notch the moment you see it. Ask when you need it.",
  "hero.try": "Drag a card into the notch",
  "frag.file": "Q3 Market Report.pdf",
  "frag.file.m": "12 pages · from Slack",
  "frag.chat.n": "Lena",
  "frag.chat": "Is the pricing page ready? Need it for tomorrow's launch",
  "frag.voice": "“$12 a month, $99 a year, export on annual.”",
  "frag.voice.m": "Q4 launch sync · 31:00 recording",
  "frag.chart": "Weekly active users",
  "frag.quote": "Teams that write decisions down ship 30% faster.",
  "frag.note.t": "Interview · Ana",
  "frag.note": "Export is too slow, wants shared folders",
  "hero.download": "Download for macOS",
  "f.drop.t": "Drop it on the notch. Done.",
  "f.drop.d": "It writes the title, summary and tags.",
  "f.text.t": "Select text. Press once.",
  "f.text.d": "The app and window it came from are kept too.",
  "f.shot.t": "Frame a piece of the screen.",
  "f.shot.d": "Captures are read and filed like any file.",
  "f.ask.t": "Then just ask.",
  "f.ask.d": "Answers come from what you saved, with sources.",
  "f.meet.t": "After the meeting, the to-dos are there.",
  "f.meet.d": "Transcribed on your Mac. Action items wait for your OK.",
  "f.rt.t": "Take it to the round table.",
  "f.rt.d": "A few AI knights discuss it, each from their own angle.",
  "f.ai.t": "Your AI can use it too.",
  "f.ai.d": "Claude Code and Codex search it and add to-dos over MCP.",
  "get.title": "Put it in your notch.",
  "get.req": "macOS 14 or later, Apple Silicon",
  "footer.feedback": "Feedback",
  "star.cta": "Star on GitHub",
  "star.note": "If casebase helps you, a star helps others find it.",
};

const ZH = {};
document.querySelectorAll("[data-i18n]").forEach((node) => { ZH[node.dataset.i18n] = node.innerHTML; });

function pickLanguage() {
  const query = new URLSearchParams(location.search).get("lang");
  if (query === "en" || query === "zh") return query;
  try { const saved = localStorage.getItem("cb-lang"); if (saved) return saved; } catch {}
  return /^zh/i.test(navigator.language || "") ? "zh" : "en";
}
let lang = pickLanguage();
const demoState = new Map(); // demo frame or video -> { playing, played, left }

// Pixel icons from the app mark each feature.
document.querySelectorAll(".mark[data-icon]").forEach((node) => {
  node.innerHTML = pixelIconSVG(node.dataset.icon, "rgba(255,255,255,0.92)", 24);
});

const notch = document.querySelector(".live-notch");

function applyLanguage() {
  const dict = lang === "en" ? EN : ZH;
  document.documentElement.lang = lang === "en" ? "en" : "zh-CN";
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const value = dict[node.dataset.i18n];
    if (value !== undefined) node.innerHTML = value;
  });
  document.querySelector("[data-lang-toggle]").textContent = lang === "en" ? "中文" : "EN";
  const liveSrc = `/demos/demo.html?scene=live&lang=${lang}`;
  if (!notch.src.endsWith(liveSrc)) notch.src = liveSrc;
  document.querySelectorAll("iframe.demo").forEach((frame) => {
    const src = `/demos/demo.html?scene=${frame.dataset.scene}&lang=${lang}&embed=1&nocaption=1&crop=${frame.dataset.crop}`;
    if (frame.dataset.loaded) frame.src = src;
    frame.dataset.src = src;
    demoState.delete(frame);
  });
  document.querySelectorAll("video.demo-video").forEach((video) => {
    video.dataset.src = lang === "en" ? video.dataset.srcEn : video.dataset.srcZh;
    video.poster = lang === "en" ? video.dataset.posterEn : video.dataset.posterZh;
    if (video.getAttribute("src")) { video.src = video.dataset.src; video.play().catch(() => {}); }
  });
}

document.querySelector("[data-lang-toggle]").addEventListener("click", () => {
  lang = lang === "en" ? "zh" : "en";
  try { localStorage.setItem("cb-lang", lang); } catch {}
  applyLanguage();
});
applyLanguage();

// ---------------------------------------------------------------------------
// The live notch: the page decides when the pointer is over it; once open, the
// frame takes the pointer until it moves off the panel.

let notchRect = { x: 327.5, y: 0, w: 185, h: 33 };
let hovering = false;
let notchBusyUntil = 0;
const frameScale = () => Math.min(1, window.innerWidth / 840);

function placeNotch() {
  notch.style.transform = `scale(${frameScale()})`;
  notch.style.transformOrigin = "50% 0";
}
placeNotch();
window.addEventListener("resize", placeNotch);

function pageRect() {
  const scale = frameScale();
  const left = window.innerWidth / 2 - 420 * scale;
  return { x: left + notchRect.x * scale, y: 0, w: notchRect.w * scale, h: notchRect.h * scale };
}

function setHover(value) {
  if (value === hovering) return;
  // The hero animation and the answer after a drag-in play through; the menu waits for them.
  if (value && (autoplay || answering)) return;
  hovering = value;
  notch.style.pointerEvents = value ? "auto" : "none";
  notch.contentWindow?.postMessage({ type: "cb-live", hover: value }, "*");
  if (value) document.body.classList.add("notch-tried");
}

window.addEventListener("mousemove", (event) => {
  // While open, the frame takes the pointer; a move the page still sees is outside it.
  if (hovering) { setHover(false); return; }
  // A card in hand, or one just dropped and still being saved, owns the notch.
  if (document.body.classList.contains("dragging-card") || performance.now() < notchBusyUntil) return;
  const r = pageRect();
  const pad = 16 * frameScale();
  if (event.clientX >= r.x - pad && event.clientX <= r.x + r.w + pad && event.clientY <= r.h + pad) setHover(true);
});

// Touch screens have no hover: a tap on the notch opens it, a tap elsewhere closes it.
window.addEventListener("touchstart", (event) => {
  const touch = event.touches[0];
  const r = pageRect();
  const inside = touch.clientX >= r.x - 20 && touch.clientX <= r.x + r.w + 20 && touch.clientY <= r.h + 20;
  if (inside && !hovering) setHover(true);
  else if (!inside && hovering) setHover(false);
}, { passive: true });

window.addEventListener("message", (event) => {
  if (event.source !== notch.contentWindow || !event.data) return;
  if (event.data.type === "cb-live-rect") {
    notchRect = event.data.rect;
    // The notch is open when it is taller than the menu bar row.
    document.body.classList.toggle("notch-focus", notchRect.h > 120 && window.scrollY < window.innerHeight * 0.6);
  }
  if (event.data.type === "cb-live-leave") setHover(false);
});

// ---------------------------------------------------------------------------
// Demos load as they approach, start once the frame is well in view, hold their
// frame when scrolled mostly away, and start over only after leaving the screen.

const send = (frame, action) => frame.contentWindow && frame.contentWindow.postMessage({ type: "cb-demo", action }, "*");

function control(node, action) {
  if (node.tagName === "IFRAME") { send(node, action); return; }
  if (action === "start") { node.currentTime = 0; node.play().catch(() => {}); }
  else if (action === "resume") node.play().catch(() => {});
  else node.pause();
}

function onRatio(node, ratio) {
  const state = demoState.get(node) || { playing: false, played: false, left: true };
  demoState.set(node, state);
  if (ratio > 0 && !node.dataset.loaded) {
    node.dataset.loaded = "1";
    node.src = node.dataset.src;
  }
  if (ratio === 0) state.left = true;
  if (!state.playing && ratio >= 0.7) {
    control(node, state.left || !state.played ? "start" : "resume");
    state.playing = true;
    state.played = true;
    state.left = false;
  } else if (state.playing && ratio < 0.2) {
    control(node, "pause");
    state.playing = false;
  }
}

const visibility = new IntersectionObserver((entries) => {
  for (const entry of entries) onRatio(entry.target, entry.isIntersecting ? entry.intersectionRatio : 0);
}, { threshold: [0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 1], rootMargin: "0px" });
document.querySelectorAll("iframe.demo, video.demo-video").forEach((node) => visibility.observe(node));
window.addEventListener("message", (event) => {
  if (!event.data || event.data.type !== "cb-demo-ready") return;
  const frame = [...document.querySelectorAll("iframe.demo")].find((node) => node.contentWindow === event.source);
  const state = frame && demoState.get(frame);
  if (state && state.playing) send(frame, "start");
});

const reveal = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    if (entry.isIntersecting) { entry.target.classList.add("in"); reveal.unobserve(entry.target); }
  }
}, { threshold: 0.15 });
document.querySelectorAll(".feature > *, .get > *").forEach((node) => { node.classList.add("reveal"); reveal.observe(node); });

// ---------------------------------------------------------------------------
// Hero: work fragments fly into the notch (the app's capture flight), then the
// notch answers a question from them. Visitors can drag a card in themselves.

const fragments = [...document.querySelectorAll(".frag")];
const tryHint = document.querySelector(".try");
const live = (message) => notch.contentWindow?.postMessage({ type: "cb-live", ...message }, "*");
const flightTiming = (x) => {
  // cubic-bezier(0.18, 0.94, 0.18, 1), the app's capture flight curve
  const sample = (a, b, t) => 3 * a * (1 - t) * (1 - t) * t + 3 * b * (1 - t) * t * t + t * t * t;
  let lo = 0, hi = 1, t = x;
  for (let i = 0; i < 30; i++) { t = (lo + hi) / 2; if (sample(0.18, 0.18, t) < x) lo = t; else hi = t; }
  return sample(0.94, 1, t);
};
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function notchCenter() {
  const r = pageRect();
  return { x: r.x + r.w / 2, y: (16 * frameScale()) };
}

// Autoplay flights belong to a generation; taking over with a drag ends the generation
// and sends cards still in the air back to their places.
let flightGeneration = 0;

function fly(card, offset = { x: 0, y: 0 }, auto = false) {
  const generation = flightGeneration;
  return new Promise((resolve) => {
    const box = card.getBoundingClientRect();
    const start = { x: box.left + box.width / 2, y: box.top + box.height / 2 };
    const end = notchCenter();
    const distance = Math.hypot(end.x - start.x, end.y - start.y);
    const arc = clamp(Math.max(118, distance * 0.24), 118, 240);
    const c1 = { x: start.x + (end.x - start.x) * 0.18, y: start.y - arc };
    const c2 = { x: start.x + (end.x - start.x) * 0.78, y: end.y - arc * 0.58 };
    const turn = clamp((end.x - start.x) / 240, -1, 1) * 6;
    card.classList.add("flying");
    live({ ingest: card.dataset[lang === "en" ? "thoughtEn" : "thoughtZh"] });
    const began = performance.now();
    const step = () => {
      if (auto && generation !== flightGeneration) {
        card.classList.remove("flying");
        card.style.transform = card.style.opacity = card.style.filter = "";
        resolve();
        return;
      }
      const p = flightTiming(Math.min(1, (performance.now() - began) / 1080));
      const u = 1 - p;
      const bez = (a, b, c, d) => u * u * u * a + 3 * u * u * p * b + 3 * u * p * p * c + p * p * p * d;
      const x = bez(start.x, c1.x, c2.x, end.x) - start.x + offset.x;
      const y = bez(start.y, c1.y, c2.y, end.y) - start.y + offset.y;
      const terminal = clamp((p - 0.76) / 0.24, 0, 1);
      const sx = Math.max(0.08, 1 + Math.sin(p * Math.PI) * 0.06 - terminal * 0.56) * (1 - p * 0.45);
      const sy = Math.max(0.08, 1 - Math.sin(p * Math.PI) * 0.05 - terminal * 0.64) * (1 - p * 0.45);
      card.style.transform = `translate(${x}px, ${y}px) rotate(${turn * (1 - terminal)}deg) scale(${sx}, ${sy})`;
      card.style.opacity = String(Math.max(0, 1 - terminal * 1.1));
      card.style.filter = `blur(${terminal * 12}px)`;
      if (p < 1) requestAnimationFrame(step);
      else {
        card.classList.remove("flying");
        card.classList.add("gone");
        card.style.transform = card.style.opacity = card.style.filter = "";
        resolve();
      }
    };
    requestAnimationFrame(step);
  });
}

function bringBack() {
  for (const card of fragments) {
    card.classList.add("back");
    card.classList.remove("gone");
    setTimeout(() => card.classList.remove("back"), 700);
  }
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let autoplay = true;
let heroRun = 0;
let heroVisible = true;

// Plays once: the cards fly in, the notch answers from them, the cards come back.
async function playHero(run = heroRun) {
  const playing = () => autoplay && run === heroRun;
  while (playing() && !heroVisible) await wait(400);
  await wait(1400);
  for (const card of fragments) {
    if (!playing()) return;
    if (card.offsetParent === null || card.classList.contains("gone")) continue;
    fly(card, undefined, true);
    await wait(520);
  }
  await wait(900);
  if (!playing()) return;
  strike();
  await wait(700);
  if (!playing()) return;
  live({ ask: true });
  await wait(lang === "en" ? 9000 : 10000);
  if (!playing()) return;
  stopAutoplay();
}

// Dragging a card or scrolling down ends the animation and hands the hero to the visitor.
function stopAutoplay() {
  if (!autoplay) return;
  autoplay = false;
  heroRun++;
  flightGeneration++;
  live({ reset: true });
  unstrike();
  bringBack();
  tryHint.classList.add("show");
}

window.addEventListener("scroll", () => { if (autoplay && window.scrollY > 60) stopAutoplay(); }, { passive: true });
new IntersectionObserver(([entry]) => { heroVisible = entry.isIntersecting; }, { threshold: 0.3 }).observe(document.querySelector(".hero"));
notch.addEventListener("load", () => setTimeout(playHero, 300), { once: true });

// Once every visible card is in, the notch answers from them, then the cards come back for another go.
let answering = false;
async function answerWhenAllIn() {
  if (answering || !fragments.every((c) => c.classList.contains("gone") || c.offsetParent === null)) return;
  answering = true;
  strike();
  await wait(700);
  live({ ask: true });
  await wait(lang === "en" ? 9000 : 10000);
  live({ reset: true });
  unstrike();
  await wait(600);
  bringBack();
  answering = false;
}

// Drag a card; near the top it opens the notch's drop zone, and letting go there sends it in.
const nearNotch = (x, y) => {
  const target = notchCenter();
  return y < Math.max(300, window.innerHeight * 0.36) && Math.abs(x - target.x) < Math.max(340, window.innerWidth * 0.28);
};
for (const card of fragments) {
  card.addEventListener("pointerdown", (event) => {
    if (card.classList.contains("flying") || card.classList.contains("gone")) return;
    event.preventDefault();
    stopAutoplay();
    card.setPointerCapture(event.pointerId);
    card.classList.add("dragging");
    document.body.classList.add("dragging-card");
    const origin = { x: event.clientX, y: event.clientY };
    let delta = { x: 0, y: 0 };
    let over = false;
    const move = (e) => {
      delta = { x: e.clientX - origin.x, y: e.clientY - origin.y };
      card.style.transform = `translate(${delta.x}px, ${delta.y}px) rotate(${delta.x * 0.02}deg)`;
      const near = nearNotch(e.clientX, e.clientY);
      if (near !== over) { over = near; live({ dropTarget: near }); }
    };
    const up = (e) => {
      card.removeEventListener("pointermove", move);
      card.removeEventListener("pointerup", up);
      card.removeEventListener("pointercancel", up);
      card.classList.remove("dragging");
      document.body.classList.remove("dragging-card");
      if (nearNotch(e.clientX, e.clientY)) {
        notchBusyUntil = performance.now() + 4300;
        fly(card, delta).then(answerWhenAllIn);
      } else {
        if (over) live({ dropTarget: false });
        card.style.transition = "transform 0.45s cubic-bezier(.2,.8,.2,1.2)";
        card.style.transform = "";
        setTimeout(() => { card.style.transition = ""; }, 460);
      }
    };
    card.addEventListener("pointermove", move);
    card.addEventListener("pointerup", up);
    card.addEventListener("pointercancel", up);
  });
}

// ---------------------------------------------------------------------------
// Type: headlines rise in letter by letter; the quote gets struck out once the
// fragments are in the notch, because you no longer need to say it.

function splitLetters(node) {
  const walk = (parent) => {
    for (const child of [...parent.childNodes]) {
      if (child.nodeType === Node.TEXT_NODE) {
        const fragment = document.createDocumentFragment();
        for (const word of child.textContent.split(/(\s+)/)) {
          if (!word) continue;
          if (/^\s+$/.test(word)) { fragment.append(word); continue; }
          const wrap = document.createElement("span");
          wrap.className = "word";
          for (const letter of word) {
            const span = document.createElement("span");
            span.className = "char";
            span.textContent = letter;
            wrap.append(span);
          }
          fragment.append(wrap);
        }
        child.replaceWith(fragment);
      } else if (child.nodeType === Node.ELEMENT_NODE && child.tagName !== "BR") {
        walk(child);
      }
    }
  };
  walk(node);
  node.querySelectorAll(".char").forEach((span, index) => span.style.setProperty("--i", index));
  node.classList.add("split");
}

function strike() { document.querySelector(".hero h1 .quote")?.classList.add("struck"); }
function unstrike() { document.querySelector(".hero h1 .quote")?.classList.remove("struck"); }

function splitAll() {
  document.querySelectorAll(".hero h1, .feature h2, .get h2").forEach(splitLetters);
}
splitAll();
document.querySelector("[data-lang-toggle]").addEventListener("click", () => setTimeout(splitAll, 0));

// ---------------------------------------------------------------------------
// GitHub stars: show the live count when GitHub answers in time; the buttons work either way.

const showStars = (count) => {
  if (typeof count !== "number") return;
  const text = count >= 1000 ? `${(count / 1000).toFixed(1)}k` : String(count);
  document.querySelectorAll("[data-stars]").forEach((node) => { node.textContent = text; node.hidden = false; });
};
(async () => {
  // First the count saved with the site, then a live one from GitHub if it answers in time.
  try { showStars((await (await fetch("/stars.json", { cache: "no-cache" })).json()).stars); } catch {}
  try {
    const controller = new AbortController();
    setTimeout(() => controller.abort(), 4000);
    const response = await fetch("https://api.github.com/repos/Raozhu/casebase", { signal: controller.signal });
    if (response.ok) showStars((await response.json()).stargazers_count);
  } catch {}
})();
