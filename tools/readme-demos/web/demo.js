// casebase notch demos rendered in HTML. Open demo.html?scene=drop&lang=zh to play.
// The recorder calls window.casebaseDemo.seek(t) for each frame instead.

import {
  Track, el, escapeHTML, notchPath, pixelIconSVG, pixelGlyphSVG, pixelTextHTML,
  TONES, rgb, withAlpha, easeInOut, bezierTiming,
} from "./engine.js";
import { PIXEL_PATTERNS } from "./icons.js";

const params = new URLSearchParams(location.search);
const LANG = params.get("lang") === "zh" ? "zh" : "en";
const L = (en, zh) => (LANG === "zh" ? zh : en);

const CX = 420; // notch center in the 840pt-wide clip
const NOTCH = { w: 185, h: 33 };
const LEADING_EXTENSION = 34;
const CONTENT_PADDING = 16;
const TOP_INSET = 17; // displayCutout height - contentPadding + 1
const RAIL_TOP = 40; // cutout height + taskRailVerticalSpacing

// ---------------------------------------------------------------------------
// Demo copy (the same made-up data as tools/readme-demos/Content.swift)

const T = {
  dropCaption: L("Drag a file onto the notch", "把文件拖到刘海上"),
  readCaption: L("casebase reads the file and files it", "casebase 读取内容并归类"),
  libraryCaption: L("It's in your library, already titled", "已经存进资料库，标题也起好了"),
  openCaption: L("Open it to see the summary and tags", "点开查看摘要和标签"),
  dropHere: L("Drop Here", "放这里"),
  preparing: L("Preparing the asset and import context", "正在准备原件与导入上下文"),
  storing: L("Writing into the knowledge store", "正在写入资料库"),
  saved: L("Saved to casebase", "已完成入库"),
  libraryTitle: L("Stored Data", "已存数据"),
  reportFile: L("Q3 Market Report.pdf", "Q3 市场报告.pdf"),
  textCaption: L("Select text and press ⌘F1", "选中文字，按 ⌘F1"),
  shotCaption: L("Press ⌘F2 and select an area", "按 ⌘F2，框选一块区域"),
  savingCaption: L("casebase reads it and files it", "casebase 读取内容并归类"),
  articleTitle: L("Why async teams ship faster", "为什么异步团队交付更快"),
  articleLines: [
    L("Most delays don't come from slow work. They come from waiting:", "大多数延期不是因为干得慢，而是因为等待："),
    L("for a meeting, for an answer, for someone to remember a decision.", "等开会、等答复、等有人想起当初是怎么定的。"),
  ],
  articleQuote: L("Teams that write decisions down ship 30% faster.", "把决定写下来的团队，交付速度快 30%。"),
  articleTail: L("The habit is simple: one line per decision, where everyone can find it.", "做法很简单：每个决定写一行，放在大家都找得到的地方。"),
  clipThoughts: [
    L("A highlighted line from an article on async teams.", "这是文章里划出的一句话，讲异步协作。"),
    L("Key claim: writing decisions down speeds delivery 30%.", "要点：把决定写下来，交付快 30%。"),
    L("Filing it under Research.", "归到「调研」。"),
  ],
  chartTitle: L("Weekly active users", "周活跃用户"),
  chartSubtitle: L("After the onboarding redesign", "新手引导改版后"),
  shotThoughts: [
    L("A bar chart of weekly active users.", "这是一张周活跃用户柱状图。"),
    L("Up from 9.2k to 18.4k in six weeks.", "六周内从 9200 涨到 18400。"),
    L("Filing it under Metrics.", "归到「数据指标」。"),
  ],
  thoughts: [
    L("A 12-page quarterly market report.", "这是一份 12 页的季度市场报告。"),
    L("Key numbers: APAC revenue +38%, churn 2.1%.", "关键数字：亚太区收入 +38%，流失率 2.1%。"),
    L("Filing it under Reports.", "归到「报告」。"),
  ],
};

const KIND = {
  pdf: { label: "PDF", detail: L("PDF document", "PDF 文档"), icon: "pdf", tone: "danger", tint: [0.66, 0.28, 0.25] },
  text: { label: L("Text", "文本"), detail: L("Text content", "文本内容"), icon: "text", tone: "success", tint: [0.23, 0.58, 0.48] },
  image: { label: L("Image", "图片"), detail: L("Image preview", "图片缩略图"), icon: "image", tone: "accent", tint: [0.22, 0.47, 0.88] },
};

// LibraryInfoPill colors per tone
const PILL = {
  danger: { fg: rgb(1.0, 0.72, 0.72), bg: [0.32, 0.10, 0.12] },
  success: { fg: rgb(0.82, 1.0, 0.74), bg: [0.08, 0.23, 0.14] },
  accent: { fg: rgb(0.70, 0.83, 1.0), bg: [0.12, 0.24, 0.42] },
};

const stamp = (hh, mm, day = 21) =>
  LANG === "zh"
    ? `2026年10月${day}日 ${hh}:${String(mm).padStart(2, "0")}`
    : `Oct ${day}, 2026 at ${((hh + 11) % 12) + 1}:${String(mm).padStart(2, "0")}\u202F${hh < 12 ? "AM" : "PM"}`;

const RECORDS = {
  report: {
    kind: "pdf", title: L("Q3 Market Report: APAC leads growth", "Q3 市场报告：亚太区领跑增长"),
    scene: L("Quarterly business review", "季度经营复盘"), purpose: L("Reports", "报告"), time: stamp(10, 24),
    summary: L("Quarterly market report. APAC revenue grew 38% quarter over quarter and churn fell to 2.1%. It recommends doubling the APAC sales team.",
      "季度市场报告。亚太区收入环比增长 38%，流失率降到 2.1%，建议把亚太销售团队扩大一倍。"),
    tags: [L("Market report", "市场报告"), "Q3", L("APAC", "亚太")], fileName: L("Q3 Market Report.pdf", "Q3 市场报告.pdf"),
  },
  meeting: {
    kind: "text", title: L("Q4 launch sync", "Q4 发布同步会"), scene: L("Team meeting", "团队会议"), purpose: L("Meetings", "会议"), time: stamp(8, 31),
    summary: L("Launch pricing set at $12/month or $99/year, with the export add-on on annual plans.", "发布定价定为月付 12 美元、年付 99 美元，年付含导出功能。"),
    tags: [L("Meeting", "会议"), L("Pricing", "定价"), L("Launch", "发布")], fileName: L("Q4 launch sync.txt", "Q4 发布同步会.txt"),
  },
  clip: {
    kind: "text", title: L("Writing decisions down speeds delivery by 30%", "把决定写下来，交付快 30%"),
    scene: L("Article excerpt", "文章摘录"), purpose: L("Research", "调研"), time: stamp(10, 31),
    summary: L("A line from an article on async teams: teams that write decisions down ship about 30% faster.",
      "一篇讲异步协作的文章里的一句话：把决定写下来的团队，交付速度快约 30%。"),
    tags: [L("Async work", "异步协作"), L("Decisions", "决策记录"), L("Research", "调研")], fileName: "Safari Selection",
  },
  shot: {
    kind: "image", title: L("Weekly active users: 18.4k in week 6", "周活跃用户：第 6 周达到 1.84 万"),
    scene: L("Product metrics", "产品数据"), purpose: L("Metrics", "数据指标"), time: stamp(10, 36), thumbnail: true,
    summary: L("Bar chart of weekly active users over six weeks, climbing from 9.2k to 18.4k after the onboarding redesign.",
      "六周周活跃用户柱状图，新手引导改版后从 9200 增长到 18400。"),
    tags: [L("Metrics", "数据指标"), L("Growth", "增长")], fileName: "Safari Screenshot.png",
  },
  pricing: { kind: "text", title: L("Pricing research notes", "定价调研笔记"), scene: L("Pricing research", "定价调研"), time: stamp(9, 12, 20) },
  interview: { kind: "text", title: L("Interview: Ana, product designer", "访谈：安娜，产品设计师"), scene: L("User research", "用户研究"), time: stamp(15, 40, 19) },
  contract: { kind: "pdf", title: L("Supplier agreement 2026", "2026 供应商协议"), scene: L("Procurement", "采购"), time: stamp(11, 5, 18) },
};

const STATUS_READY = L("Ready", "已完成");
const DETAIL = {
  title: L("Details", "查看详情"), metadata: L("Metadata", "基础信息"), updated: L("Updated", "更新时间"), fileName: L("File name", "文件名"),
  type: L("Type", "类型"), scene: L("Scene", "场景"), purpose: L("Purpose", "用途"), parse: L("Parse status", "解析状态"), tags: L("Tags", "标签"),
  reveal: L("Reveal", "定位"), open: L("Open", "打开"), discuss: L("Discuss", "带到圆桌"), delete: L("Delete", "删除"),
};

// ---------------------------------------------------------------------------
// Stage

const stage = el("div", `cb-stage cb-${LANG}`);
const STAGE_HEIGHT = params.get("scene") === "ask" ? 760 : 680;
stage.style.height = `${STAGE_HEIGHT}px`;
document.getElementById("demo").appendChild(stage);

const LIVE = params.get("scene") === "live";
if (!LIVE) {
  stage.appendChild(el("div", "cb-wallpaper"));
  stage.appendChild(el("div", "cb-menubar"));
} else {
  stage.style.background = "transparent";
}

const desktopFile = el("div", "cb-desktop-file", `<img src="assets/pdf.png" alt=""><span>${escapeHTML(T.reportFile)}</span>`);
stage.appendChild(desktopFile);

// A Safari-like window, the source of the selected text and of the screenshot.
const WINDOW_FRAME = { x: 120, y: 150, w: 600, h: 340 };
const appWindow = el("div", "cb-window");
Object.assign(appWindow.style, { left: `${WINDOW_FRAME.x}px`, top: `${WINDOW_FRAME.y}px`, width: `${WINDOW_FRAME.w}px`, height: `${WINDOW_FRAME.h}px`, display: "none" });
stage.appendChild(appWindow);

function windowChrome(url, body) {
  return `<div class="cb-window-bar"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i>
    <span class="cb-url">${pixelFreeLock()}${escapeHTML(url)}</span></div><div class="cb-window-body">${body}</div>`;
}
function pixelFreeLock() {
  return `<svg width="9" height="11" viewBox="0 0 9 11"><rect x="0.5" y="4.5" width="8" height="6" rx="1.5" fill="currentColor"/><path d="M2.3 4.6V3.2a2.2 2.2 0 0 1 4.4 0v1.4" fill="none" stroke="currentColor" stroke-width="1.2"/></svg>`;
}
function articleHTML() {
  return windowChrome("blog.example.com/async-teams", `
    <div class="cb-article">
      <h1>${escapeHTML(T.articleTitle)}</h1>
      ${T.articleLines.map((line) => `<p>${escapeHTML(line)}</p>`).join("")}
      <p class="cb-quote"><span class="cb-sel">${escapeHTML(T.articleQuote)}</span></p>
      <p>${escapeHTML(T.articleTail)}</p>
    </div>`);
}
const BARS = [["W1", 9200], ["W2", 10400], ["W3", 12100], ["W4", 13900], ["W5", 16200], ["W6", 18400]];
function chartHTML() {
  const max = Math.max(...BARS.map((b) => b[1]));
  return windowChrome("analytics.example.com/growth", `
    <div class="cb-chart">
      <div class="cb-chart-title">${escapeHTML(T.chartTitle)}</div>
      <div class="cb-chart-subtitle">${escapeHTML(T.chartSubtitle)}</div>
      <div class="cb-bars">${BARS.map(([label, value], i) => `
        <div class="cb-bar"><span class="cb-bar-value">${value}</span>
          <span class="cb-bar-fill" style="height:${(value / max) * 150}px;opacity:${i === BARS.length - 1 ? 1 : 0.35}"></span>
          <span class="cb-bar-label">${label}</span></div>`).join("")}</div>
    </div>`);
}

// ScreenshotCaptureOverlayView: dimmed screen with a rounded selection and eight handles.
const shotSVG = document.createElementNS("http://www.w3.org/2000/svg", "svg");
shotSVG.setAttribute("class", "cb-shot-overlay");
shotSVG.setAttribute("width", "840");
shotSVG.setAttribute("height", "680");
stage.appendChild(shotSVG);

const notchSVG = document.createElementNS("http://www.w3.org/2000/svg", "svg");
notchSVG.setAttribute("class", "cb-notch-shape");
notchSVG.setAttribute("width", "840");
notchSVG.setAttribute("height", String(STAGE_HEIGHT));
notchSVG.innerHTML = `<defs><filter id="cb-notch-shadow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur in="SourceAlpha" stdDeviation="8"/><feComponentTransfer><feFuncA type="linear" slope="1" id="cb-shadow-alpha"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs><path id="cb-notch-path" fill="#000" filter="url(#cb-notch-shadow)"/>`;
stage.appendChild(notchSVG);
const notchPathEl = notchSVG.querySelector("#cb-notch-path");
const shadowAlpha = notchSVG.querySelector("#cb-shadow-alpha");

// Capture "sink" glow on the notch (NotchBackgroundView overlay, screen blend)
const sinkLayer = el("div", "cb-sink", `<span class="cb-sink-glow"></span><span class="cb-sink-ring"></span><span class="cb-sink-bar"></span>`);
stage.appendChild(sinkLayer);
const [sinkGlow, sinkRing, sinkBar] = sinkLayer.children;

const indicator = el("div", "cb-indicator");
stage.appendChild(indicator);

const rail = el("div", "cb-rail", `<span class="cb-rail-text"></span>`);
stage.appendChild(rail);
const railText = rail.querySelector(".cb-rail-text");

const composite = el("div", "cb-composite");
const panel = el("div", "cb-panel");
composite.appendChild(panel);
stage.appendChild(composite);

// SelectionCaptureFlightView: the captured text or image flying into the notch.
// Its scale and rotation pivot on the screen center, as in the app.
const flightLayer = el("div", "cb-flight-layer");
const flightTile = el("div", "cb-flight-tile");
flightLayer.appendChild(flightTile);
stage.appendChild(flightLayer);

const overlay = el("div", "cb-layer");
const keysHUD = el("div", "cb-keys");
overlay.appendChild(keysHUD);
const dragIcon = el("img", "cb-drag-icon");
dragIcon.src = "assets/pdf.png";
const cursor = el("img", "cb-cursor");
cursor.src = "assets/cursor.png";
const caption = el("div", "cb-caption");
overlay.append(dragIcon, cursor, caption);
stage.appendChild(overlay);

// ---------------------------------------------------------------------------
// Notch content views

function contentShell(bodyHTML, { chrome = "" } = {}) {
  const node = el("div", "cb-content", `<div class="cb-chrome-row">${chrome}</div><div class="cb-body">${bodyHTML}</div>`);
  node.style.display = "none";
  panel.appendChild(node);
  return node;
}

const dropZone = contentShell(`
  <div class="cb-dropzone"><div class="cb-dropzone-box"><svg class="cb-dash"></svg>
    <div class="cb-dropzone-label"><span class="cb-float">${pixelIconSVG("box", TONES.neutral.glyph, 24)}</span><span>${escapeHTML(T.dropHere)}</span></div>
  </div></div>`);
const dropDash = dropZone.querySelector(".cb-dash");
const dropFloat = dropZone.querySelector(".cb-float");
dropFloat.style.filter = `drop-shadow(0 2px 3px rgba(255,255,255,0.1))`;
dropZone.querySelector(".cb-dropzone-box").style.filter = "drop-shadow(0 8px 16px rgba(255,255,255,0.08))";

// The captured screenshot region, rebuilt from the window markup and scaled to fill a box.
const SHOT_RECT = { x: WINDOW_FRAME.x + 14, y: WINDOW_FRAME.y + 56, w: WINDOW_FRAME.w - 28, h: WINDOW_FRAME.h - 68 };
function shotThumbHTML(width, height, radius) {
  const scale = Math.max(width / SHOT_RECT.w, height / SHOT_RECT.h);
  const ox = (width - SHOT_RECT.w * scale) / 2 - (SHOT_RECT.x - WINDOW_FRAME.x) * scale;
  const oy = (height - SHOT_RECT.h * scale) / 2 - (SHOT_RECT.y - WINDOW_FRAME.y) * scale;
  return `<span class="cb-thumb" style="border-radius:${radius}px"><span class="cb-window cb-window-static" style="width:${WINDOW_FRAME.w}px;height:${WINDOW_FRAME.h}px;transform:translate(${ox}px,${oy}px) scale(${scale});box-shadow:none">${chartHTML()}</span></span>`;
}

function previewHTML(record, size, radius, iconSize) {
  const kind = KIND[record.kind];
  const background = `linear-gradient(135deg, ${rgb(...kind.tint, 0.28)}, rgba(255,255,255,0.04))`;
  if (record.thumbnail) return `<div class="cb-preview" style="background:${background}">${shotThumbHTML(size, size, radius)}</div>`;
  return `<div class="cb-preview" style="background:${background}">
        ${pixelIconSVG(kind.icon, TONES[kind.tone].glyph, iconSize)}
        <div><div class="cb-preview-kind">${escapeHTML(kind.label)}</div><div class="cb-preview-detail">${escapeHTML(kind.detail)}</div></div>
      </div>`;
}

function recordRow(record) {
  const kind = KIND[record.kind];
  const pill = PILL[kind.tone];
  return `
    <div class="cb-row">
      ${previewHTML(record, 64, 18, 24)}
      <div class="cb-row-main">
        <div class="cb-row-text">
          <div class="cb-row-titleline">
            <span class="cb-pill" style="color:${pill.fg};background:${rgb(...pill.bg)};box-shadow:inset 0 0 0 1px ${rgb(...pill.bg, 0.12)}">${escapeHTML(kind.label)}</span>
            <span class="cb-row-title">${escapeHTML(record.title)}</span>
          </div>
          <div class="cb-row-scene">${escapeHTML(record.scene)}</div>
          <div class="cb-row-time">${escapeHTML(record.time)}</div>
        </div>
        <div class="cb-row-trailing">
          <span style="filter:drop-shadow(0 2px 3px ${withAlpha(TONES.success.glyph, 0.08)})">${pixelIconSVG("check", TONES.success.glyph, 16)}</span>
          ${pixelIconSVG("replyAll", "rgba(255,255,255,0.34)", 11)}
        </div>
      </div>
    </div>`;
}

function libraryView(records) {
  return contentShell(`
    <div class="cb-library">
      <div class="cb-header">
        <span class="cb-title">${escapeHTML(T.libraryTitle)}</span>
        <span class="cb-count">${pixelTextHTML(String(records.length), TONES.neutral.glyph, 9)}</span>
        <span class="cb-spacer"></span>
        <span class="cb-chrome-button">${pixelIconSVG("chevronLeft", "rgba(255,255,255,0.84)", 13)}</span>
      </div>
      <div class="cb-rows">${records.map(recordRow).join("")}</div>
    </div>`);
}

function pill(text, tone, icon) {
  const colors = PILL[tone];
  const iconHTML = icon ? pixelIconSVG(icon, colors.fg, 10) : "";
  return `<span class="cb-pill${icon ? " cb-pill-icon" : ""}" style="color:${colors.fg};background:${rgb(...colors.bg)};box-shadow:inset 0 0 0 1px ${rgb(...colors.bg, 0.12)}">${iconHTML}${escapeHTML(text)}</span>`;
}

function tile(icon, title, destructive = false) {
  const color = destructive ? "rgb(255,189,189)" : "rgba(255,255,255,0.86)";
  return `<span class="cb-tile${destructive ? " cb-destructive" : ""}">${pixelIconSVG(icon, color, 14)}<span>${escapeHTML(title)}</span></span>`;
}

const valueRow = (label, value) =>
  `<div class="cb-value"><span class="cb-value-label">${escapeHTML(label)}</span><span class="cb-value-text">${escapeHTML(value)}</span></div>`;

function detailView(record) {
  const kind = KIND[record.kind];
  return contentShell(`
    <div class="cb-detail">
      <div class="cb-header">
        <span class="cb-title">${escapeHTML(DETAIL.title)}</span>
        <span class="cb-spacer"></span>
        <span class="cb-chrome-button">${pixelIconSVG("chevronLeft", "rgba(255,255,255,0.84)", 13)}</span>
      </div>
      <div class="cb-detail-body">
        <div class="cb-detail-scroll"><div class="cb-detail-cards">
          <div class="cb-glass cb-hero">
            ${previewHTML(record, 128, 26, 32)}
            <div class="cb-hero-text">
              <div class="cb-pills">${pill(kind.label, kind.tone)}${pill(STATUS_READY, "success", "check")}</div>
              <div class="cb-hero-title">${escapeHTML(record.title)}</div>
              <div class="cb-hero-summary">${escapeHTML(record.summary)}</div>
              <div class="cb-tags">${record.tags.map((tag) => `<span class="cb-tag">${escapeHTML(tag)}</span>`).join("")}</div>
              <div class="cb-facts">
                <div class="cb-fact"><span class="cb-fact-label">${escapeHTML(DETAIL.updated)}</span><span class="cb-fact-value">${escapeHTML(record.time)}</span></div>
                <div class="cb-fact"><span class="cb-fact-label">${escapeHTML(DETAIL.fileName)}</span><span class="cb-fact-value">${escapeHTML(record.fileName)}</span></div>
              </div>
            </div>
          </div>
          <div class="cb-glass cb-section">
            <span class="cb-section-title">${escapeHTML(DETAIL.metadata)}</span>
            <div class="cb-values">
              ${valueRow(DETAIL.fileName, record.fileName)}${valueRow(DETAIL.type, kind.label)}${valueRow(DETAIL.scene, record.scene)}
              ${valueRow(DETAIL.purpose, record.purpose)}${valueRow(DETAIL.parse, STATUS_READY)}${valueRow(DETAIL.updated, record.time)}
              ${valueRow(DETAIL.tags, record.tags.join(" · "))}
            </div>
          </div>
        </div></div>
        <div class="cb-actionbar">${tile("folder", DETAIL.reveal)}${tile("open", DETAIL.open)}${tile("sword", DETAIL.discuss)}${tile("trash", DETAIL.delete, true)}</div>
      </div>
    </div>`);
}

const CONTENT = {};
const PANEL_SIZE = {};
const UPDATERS = {};
function register(name, node, size, update) {
  CONTENT[name] = node;
  PANEL_SIZE[name] = size;
  if (update) UPDATERS[name] = update;
  model.contentOpacity[name] = new Track(0);
}

/** Natural height of a content view, as NotchCompositeView measures it for adaptive panels. */
function measureContent(name, width) {
  const node = CONTENT[name];
  const display = node.style.display;
  node.classList.add("cb-measuring");
  node.style.width = `${width - 36}px`;
  const height = node.offsetHeight;
  node.classList.remove("cb-measuring");
  node.style.width = "";
  node.style.display = display;
  return height;
}

// ---------------------------------------------------------------------------
// Timeline model

const model = {
  surface: new Track({ w: NOTCH.w, h: NOTCH.h, r: 8, ox: 0 }),
  shadow: new Track(0),
  composite: new Track({ w: 520, h: 269 }),
  content: new Track(null), // which content view is showing
  contentOpacity: {},
  compositeOpacity: new Track(0),
  indicator: new Track(null), // "preparing" | "recognizing" | "storing" | "success"
  indicatorOpacity: new Track(0),
  rail: new Track(0), // morph progress
  railText: new Track(""),
  railState: new Track("preparing"),
  cursor: new Track({ x: 644, y: 470 }),
  cursorPressed: new Track(0),
  dragging: new Track(0),
  desktopFile: new Track(0),
  caption: new Track(""),
  captionOpacity: new Track(0),
  dropZoneSince: 0,
  appWindow: new Track(null), // "article" | "chart"
  selection: new Track(0),
  shotRect: new Track(null),
  keys: new Track(""),
  captureSink: new Track(0),
  feedbackScale: new Track(1),
  flight: new Track(null),
  askPhase: new Track("empty"),
  draft: new Track(""),
  answerText: new Track(""),
  accepted: new Track(0),
  discussing: new Track(0),
  rtWindow: new Track(0),
  term: new Track(0),
  termTyped: new Track(""),
  termLines: new Track(-1),
  termBusy: new Track(0),
  scroll: new Track(0),
};

let clock = 0;
const at = () => clock;
const wait = (s) => { clock += s; };

function moveCursor(x, y, duration) {
  model.cursor.set(clock, { x, y }, "ease", duration);
  clock += duration;
}

function click() {
  model.cursorPressed.set(clock, 1, "step");
  model.cursorPressed.set(clock + 0.12, 0, "step");
  clock += 0.2;
}

function setCaption(text) {
  model.captionOpacity.set(clock, 0, "ease", 0.12);
  model.caption.set(clock + 0.12, text, "step");
  model.captionOpacity.set(clock + 0.12, 1, "ease", 0.25);
}

function resizePanel(height) {
  const w = model.composite.at(clock).w;
  const surfaceHeight = height + TOP_INSET + CONTENT_PADDING * 2;
  model.surface.set(clock, { w, h: surfaceHeight, r: 32, ox: 0 });
  model.composite.set(clock, { w, h: surfaceHeight });
}

function expandTo(state, override) {
  const size = override || PANEL_SIZE[state];
  const surfaceHeight = size.h + TOP_INSET + CONTENT_PADDING * 2;
  const wasExpanded = model.content.at(clock) !== null;
  model.surface.set(clock, { w: size.w, h: surfaceHeight, r: 32, ox: 0 });
  model.shadow.set(clock, 1);
  model.composite.set(clock, { w: size.w, h: surfaceHeight }, wasExpanded ? "spring" : "step");
  model.compositeOpacity.set(clock, 1);
  const previous = model.content.at(clock);
  if (previous) model.contentOpacity[previous].set(clock, 0);
  model.contentOpacity[state].set(clock, wasExpanded ? 0 : 1, wasExpanded ? "spring" : "step");
  if (wasExpanded) model.contentOpacity[state].set(clock, 1);
  model.content.set(clock, state, "step");
  if (state === "dropTarget") model.dropZoneSince = clock;
}

function collapse({ withIndicator = false } = {}) {
  const w = NOTCH.w + (withIndicator ? LEADING_EXTENSION : 0);
  model.surface.set(clock, { w, h: NOTCH.h, r: 8, ox: withIndicator ? -LEADING_EXTENSION / 2 : 0 });
  model.shadow.set(clock, 0);
  model.compositeOpacity.set(clock, 0);
  const previous = model.content.at(clock);
  if (previous) model.contentOpacity[previous].set(clock, 0);
  model.content.set(clock, null, "step");
}

function showIndicator(kind) {
  model.indicator.set(clock, kind, "step");
  model.indicatorOpacity.set(clock, 1);
}

function hideIndicator() {
  model.indicatorOpacity.set(clock, 0);
  model.surface.set(clock, { ...model.surface.at(clock), w: NOTCH.w, ox: 0 });
}

function railShow(text, state) {
  model.railText.set(clock, text, "step");
  model.railState.set(clock, state, "step");
  model.rail.set(clock, 1);
}

function railHide() {
  model.rail.set(clock, 0);
}

function pressKeys(keys, hold = 0.8) {
  model.keys.set(clock, keys.join(" "), "step");
  model.keys.set(clock + hold, "", "step");
  clock += hold;
}

// animateCaptureSink + pulseFeedback, when a capture lands in the notch
function intakePulse() {
  model.captureSink.set(clock, 1, "bouncy", [0.2, 0.62]);
  model.captureSink.set(clock + 0.17, 0, "easeOut", 0.56);
  model.feedbackScale.set(clock, 1.035, "bouncy", [0.22, 0.68]);
  model.feedbackScale.set(clock + 0.18, 1, "bouncy", [0.26, 0.82]);
}

function flyIntoNotch(kind, rect, text) {
  model.flight.set(clock, { kind, rect, text, start: clock }, "step");
  model.flight.set(clock + 1.14, null, "step");
}

/** The import as the rail shows it: preparing, streamed thinking, storing, saved. */
function runImport(thoughts) {
  const start = clock;
  if (!model.indicator.at(clock)) model.surface.set(clock, { w: NOTCH.w + LEADING_EXTENSION, h: NOTCH.h, r: 8, ox: -LEADING_EXTENSION / 2 });
  showIndicator("preparing");
  railShow(T.preparing, "preparing");
  clock = start + 0.7;
  model.indicator.set(clock, "recognizing", "step");
  model.railState.set(clock, "recognizing", "step");
  let thought = "";
  for (const sentence of thoughts) {
    for (const character of sentence) {
      thought += character;
      model.railText.set(clock, condensed(thought), "step");
      wait(0.022);
    }
    thought += " ";
    wait(0.25);
  }
  model.indicator.set(clock, "storing", "step");
  model.railState.set(clock, "storing", "step");
  model.railText.set(clock, T.storing, "step");
  wait(0.6);
  model.indicator.set(clock, "success", "step");
  model.railState.set(clock, "success", "step");
  model.railText.set(clock, T.saved, "step");
}

/** Click the "saved" rail, open the new record from the library, show its summary and tags. */
function openSavedRecord() {
  setCaption(T.libraryCaption);
  moveCursor(420, 52, 0.7);
  click();
  railHide();
  hideIndicator();
  expandTo("library");
  wait(0.9);
  moveCursor(500, 160, 0.7);
  click();
  setCaption(T.openCaption);
  expandTo("detail");
  moveCursor(744, 470, 0.8);
  wait(3.4);
}

function stageRect(node) {
  const a = node.getBoundingClientRect();
  const b = stage.getBoundingClientRect();
  return { x: a.left - b.left, y: a.top - b.top, w: a.width, h: a.height };
}

// condensedThinkingText: whitespace collapsed, at most 38 characters plus an ellipsis
function condensed(text) {
  const normalized = text.replace(/[*`_>#-]+/g, " ").replace(/\s+/g, " ").trim();
  const chars = [...normalized];
  return chars.length <= 38 ? normalized : chars.slice(0, 38).join("").trim() + "…";
}

// ---------------------------------------------------------------------------
// Scene: drag a PDF onto the notch

function sceneDrop() {
  register("dropTarget", dropZone, { w: 520, h: 220 });
  register("library", libraryView([RECORDS.report, RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  register("detail", detailView(RECORDS.report), { w: 520, h: 548 });
  model.desktopFile.set(0, 1, "step");
  wait(0.6);
  setCaption(T.dropCaption);
  moveCursor(140, 392, 0.9);
  model.cursorPressed.set(clock, 1, "step");
  wait(0.15);
  model.dragging.set(clock, 1, "step");
  model.desktopFile.set(clock, 0.45, "step");
  moveCursor(354, 230, 0.8);
  expandTo("dropTarget");
  moveCursor(416, 96, 0.6);
  wait(0.7);

  // Release: the notch collapses and the import starts.
  model.cursorPressed.set(clock, 0, "step");
  model.dragging.set(clock, 0, "step");
  model.desktopFile.set(clock, 0, "step");
  collapse({ withIndicator: true });
  setCaption(T.readCaption);
  model.cursor.set(clock, { x: 664, y: 430 }, "ease", 0.9);
  runImport(T.thoughts);
  wait(1.2);
  openSavedRecord();
  return clock;
}

// ---------------------------------------------------------------------------
// Scene: select text in Safari and press ⌘F1

function sceneText() {
  register("library", libraryView([RECORDS.clip, RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  register("detail", detailView(RECORDS.clip), { w: 520, h: 548 });
  appWindow.innerHTML = articleHTML();
  model.appWindow.set(0, "article", "step");
  model.cursor.set(0, { x: 660, y: 540 }, "step");
  appWindow.style.display = "block";
  const selection = stageRect(appWindow.querySelector(".cb-sel"));

  wait(0.6);
  setCaption(T.textCaption);
  moveCursor(selection.x + 1, selection.y + selection.h / 2, 0.8);
  model.cursorPressed.set(clock, 1, "step");
  model.selection.set(clock, 1, "linear", 0.8);
  moveCursor(selection.x + selection.w, selection.y + selection.h / 2, 0.8);
  model.cursorPressed.set(clock, 0, "step");
  wait(0.35);
  pressKeys(["⌘", "F1"], 0.7);

  const text = T.articleQuote;
  const preview = [...text].length > 20 ? [...text].slice(0, 20).join("") + "..." : text;
  flyIntoNotch("text", selection, preview);
  intakePulse();
  setCaption(T.savingCaption);
  model.cursor.set(clock, { x: 700, y: 560 }, "ease", 0.9);
  runImport(T.clipThoughts);
  wait(1.2);
  openSavedRecord();
  return clock;
}

// ---------------------------------------------------------------------------
// Scene: ⌘F2, select part of the screen

function sceneShot() {
  register("library", libraryView([RECORDS.shot, RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  register("detail", detailView(RECORDS.shot), { w: 520, h: 548 });
  appWindow.innerHTML = chartHTML();
  model.appWindow.set(0, "chart", "step");
  model.cursor.set(0, { x: 674, y: 540 }, "step");

  wait(0.6);
  setCaption(T.shotCaption);
  wait(0.4);
  pressKeys(["⌘", "F2"], 0.8);
  model.shotRect.set(clock, { x: SHOT_RECT.x, y: SHOT_RECT.y, w: 0, h: 0 }, "step");
  moveCursor(SHOT_RECT.x, SHOT_RECT.y, 0.6);
  model.cursorPressed.set(clock, 1, "step");
  model.shotRect.set(clock, { ...SHOT_RECT }, "ease", 1.05);
  moveCursor(SHOT_RECT.x + SHOT_RECT.w, SHOT_RECT.y + SHOT_RECT.h, 1.05);
  model.cursorPressed.set(clock, 0, "step");
  wait(0.35);
  model.shotRect.set(clock, null, "step");

  flyIntoNotch("image", SHOT_RECT);
  intakePulse();
  setCaption(T.savingCaption);
  model.cursor.set(clock, { x: 754, y: 520 }, "ease", 0.9);
  runImport(T.shotThoughts);
  wait(1.2);
  openSavedRecord();
  return clock;
}

// ---------------------------------------------------------------------------
// Rendering

const INDICATOR = {
  preparing: { plate: rgb(0.17, 0.18, 0.22), glyph: "rgba(255,255,255,0.86)", accent: "rgba(255,255,255,0.72)", freq: 2.8, amp: 0.02, bob: 0.8, hourglass: true },
  recognizing: { plate: rgb(0.12, 0.19, 0.28), glyph: rgb(0.82, 0.93, 1.0), accent: rgb(0.43, 0.80, 1.0), freq: 3.8, amp: 0.02, bob: 0.8, hourglass: true },
  storing: { plate: rgb(0.08, 0.22, 0.18), glyph: rgb(0.84, 1.0, 0.92), accent: rgb(0.47, 1.0, 0.78), freq: 3.2, amp: 0.02, bob: 0.8, hourglass: true },
  success: { plate: rgb(0.07, 0.24, 0.14), glyph: rgb(0.82, 1.0, 0.74), accent: rgb(0.47, 1.0, 0.67), freq: 3.4, amp: 0.03, bob: 0.4, hourglass: false },
};

const SAND = [
  ["0000000", "0011100", "0001000", "0000000", "0000000", "0000000", "0000000"],
  ["0000000", "0001000", "0001000", "0001000", "0000000", "0000000", "0000000"],
  ["0000000", "0000000", "0001000", "0001000", "0001000", "0000000", "0000000"],
  ["0000000", "0000000", "0000000", "0000000", "0001000", "0011100", "0000000"],
];

const RAIL_GLOW = { success: [0.41, 0.92, 0.62], needsInput: [1.0, 0.73, 0.22] };

let lastIndicatorKey = "";
let lastRailText = null;

function render(t) {
  const surface = model.surface.at(t);
  const cx = CX + surface.ox;

  // Notch silhouette and its shadow
  notchPathEl.setAttribute("d", notchPath(cx, surface.w, surface.h, surface.r));
  const feedback = model.feedbackScale.at(t);
  notchPathEl.setAttribute("transform", `translate(${cx} 0) scale(${feedback}) translate(${-cx} 0)`);
  shadowAlpha.setAttribute("slope", String(model.shadow.at(t)));

  // Expanded panel (NotchCompositeView)
  const compositeOpacity = model.compositeOpacity.at(t);
  const comp = model.composite.at(t);
  composite.style.opacity = compositeOpacity;
  composite.style.display = compositeOpacity < 0.005 ? "none" : "block";
  composite.style.left = `${CX - comp.w / 2}px`;
  composite.style.width = `${comp.w}px`;
  composite.style.height = `${comp.h}px`;
  composite.style.transformOrigin = "50% 0";
  composite.style.transform = `scale(${feedback})`;
  const inset = CONTENT_PADDING + 2;
  panel.style.left = `${inset}px`;
  panel.style.top = `${TOP_INSET + CONTENT_PADDING + 2}px`;
  panel.style.width = `${comp.w - inset * 2}px`;
  panel.style.height = `${comp.h - TOP_INSET - CONTENT_PADDING * 2 - 2}px`;
  for (const [key, node] of Object.entries(CONTENT)) {
    const opacity = model.contentOpacity[key].at(t);
    node.style.opacity = opacity;
    node.style.display = opacity < 0.005 ? "none" : "flex";
    if (UPDATERS[key] && opacity >= 0.005) UPDATERS[key](t);
  }

  // Drop zone: dashed border sized to the box, icon floating up and down
  if (CONTENT.dropTarget && CONTENT.dropTarget.style.display !== "none") {
    const box = dropDash.parentElement;
    const w = box.clientWidth;
    const h = box.clientHeight;
    dropDash.setAttribute("width", w);
    dropDash.setAttribute("height", h);
    dropDash.innerHTML = `<rect x="1.25" y="1.25" width="${w - 2.5}" height="${h - 2.5}" rx="16.75" fill="none" stroke="rgba(255,255,255,0.44)" stroke-width="2.5" stroke-dasharray="10 6"/>`;
    const phase = ((t - model.dropZoneSince) / 1.2) % 2;
    const p = phase < 1 ? easeInOut(phase) : 1 - easeInOut(phase - 1);
    dropFloat.style.transform = `translateY(${4 - 8 * p}px)`;
  }

  // Leading indicator (PixelCollapsedIndicatorBadge)
  const kind = model.indicator.at(t);
  const indicatorOpacity = model.indicatorOpacity.at(t);
  indicator.style.display = kind && indicatorOpacity > 0.005 ? "block" : "none";
  if (kind) {
    const style = INDICATOR[kind];
    const step = Math.floor(t / 0.26) % 4;
    const key = `${kind}:${style.hourglass ? step : ""}`;
    if (key !== lastIndicatorKey) {
      lastIndicatorKey = key;
      indicator.style.background = style.plate;
      indicator.style.boxShadow = `inset 0 0 0 1px ${withAlpha(style.accent, 0.42)}, 0 4px 16px ${withAlpha(style.accent, 0.22)}`;
      indicator.innerHTML = style.hourglass
        ? pixelGlyphSVG(PIXEL_PATTERNS.hourglass, style.glyph, 20) + pixelGlyphSVG(SAND[step], style.accent, 20)
        : pixelGlyphSVG(PIXEL_PATTERNS.check, style.glyph, 20);
    }
    const pulse = Math.sin(t * style.freq);
    const left = cx - surface.w / 2 + LEADING_EXTENSION / 2 - 10;
    indicator.style.left = `${left}px`;
    indicator.style.top = `${NOTCH.h / 2 - 10}px`;
    indicator.style.opacity = indicatorOpacity;
    indicator.style.transform = `translateY(${pulse * style.bob}px) scale(${1 + pulse * style.amp})`;
  }

  // Task rail (NotchTaskRailView) with its morph transition
  const railProgress = model.rail.at(t);
  rail.style.display = railProgress < 0.02 ? "none" : "block";
  if (railProgress >= 0.02) {
    const text = model.railText.at(t);
    const state = model.railState.at(t);
    const shimmer = state === "recognizing";
    if (text !== lastRailText) {
      lastRailText = text;
      railText.innerHTML = `${escapeHTML(text)}<span class="cb-rail-shimmer">${escapeHTML(text)}</span>`;
    }
    const glow = RAIL_GLOW[state] ? rgb(...RAIL_GLOW[state]) : "rgba(255,255,255,1)";
    rail.style.color = `rgba(255,255,255,${shimmer ? 0.42 : 0.84})`;
    rail.style.boxShadow = `inset 0 0 0 1px ${withAlpha(glow, 0.18)}, 0 8px 28px ${withAlpha(glow, 0.22)}`;
    const shimmerNode = railText.querySelector(".cb-rail-shimmer");
    shimmerNode.style.display = shimmer ? "block" : "none";
    if (shimmer) {
      const width = railText.offsetWidth;
      const highlight = Math.max(48, width * 0.7);
      const cycle = (t % 1.35) / 1.35;
      const offset = -highlight + (width + highlight * 2) * cycle;
      shimmerNode.style.backgroundImage = "linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.12), rgba(255,255,255,0.96), rgba(255,255,255,0.24), rgba(255,255,255,0))";
      shimmerNode.style.backgroundSize = `${highlight}px 100%`;
      shimmerNode.style.backgroundPosition = `${offset}px 0`;
    }
    const p = railProgress;
    rail.style.left = `${cx}px`;
    rail.style.top = `${RAIL_TOP}px`;
    rail.style.opacity = Math.min(1, p);
    rail.style.filter = `blur(${8 * (1 - p)}px)`;
    rail.style.transformOrigin = "50% 0";
    rail.style.transform = `translateX(-50%) translateY(${-8 * (1 - p)}px) scale(${0.46 + 0.54 * p}, ${0.18 + 0.82 * p})`;
  }

  renderCapture(t, cx);
  if (model.rtWindow) renderRoundTable(t);
  renderTerminal(t);

  // Desktop, cursor and caption
  const fileOpacity = model.desktopFile.at(t);
  desktopFile.style.display = fileOpacity > 0 ? "flex" : "none";
  desktopFile.style.opacity = fileOpacity;
  desktopFile.style.left = "134px";
  desktopFile.style.top = "400px";

  const pointer = model.cursor.at(t);
  cursor.style.left = `${pointer.x - 5}px`;
  cursor.style.top = `${pointer.y - 5}px`;
  cursor.style.transform = `scale(${model.cursorPressed.at(t) ? 0.86 : 1})`;
  dragIcon.style.display = model.dragging.at(t) ? "block" : "none";
  dragIcon.style.left = `${pointer.x + 6 - 32}px`;
  dragIcon.style.top = `${pointer.y + 30 - 32}px`;

  const captionText = model.caption.at(t);
  caption.textContent = captionText;
  caption.style.display = captionText && !params.has("nocaption") ? "block" : "none";
  caption.style.opacity = model.captionOpacity.at(t);
  caption.style.top = `${STAGE_HEIGHT - 34}px`;

  const keys = model.keys.at(t);
  keysHUD.style.display = keys ? "flex" : "none";
  if (keys) {
    keysHUD.innerHTML = keys.split(" ").map((key) => `<span>${escapeHTML(key)}</span>`).join("");
    keysHUD.style.transform = "translate(-50%, -50%)";
  }
}

// ---------------------------------------------------------------------------

const flightCurve = bezierTiming(0.18, 0.94, 0.18, 1);
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
let lastFlightKey = "";

function renderCapture(t, cx) {
  // Source window and text selection
  const windowKind = model.appWindow.at(t);
  appWindow.style.display = windowKind ? "block" : "none";
  const sel = appWindow.querySelector(".cb-sel");
  if (sel) {
    const p = model.selection.at(t);
    sel.style.background = p > 0 ? `linear-gradient(90deg, #b3d7ff ${p * 100}%, transparent ${p * 100}%)` : "none";
  }

  // Screenshot overlay (ScreenshotCaptureOverlayView)
  const rect = model.shotRect.at(t);
  shotSVG.style.display = rect ? "block" : "none";
  if (rect) {
    const r = Math.min(14, rect.w / 2, rect.h / 2);
    const hole = rect.w > 1 && rect.h > 1
      ? `M${rect.x + r} ${rect.y}H${rect.x + rect.w - r}A${r} ${r} 0 0 1 ${rect.x + rect.w} ${rect.y + r}V${rect.y + rect.h - r}A${r} ${r} 0 0 1 ${rect.x + rect.w - r} ${rect.y + rect.h}H${rect.x + r}A${r} ${r} 0 0 1 ${rect.x} ${rect.y + rect.h - r}V${rect.y + r}A${r} ${r} 0 0 1 ${rect.x + r} ${rect.y}Z`
      : "";
    let svg = `<path d="M0 0H840V680H0Z${hole}" fill="rgba(0,0,0,0.58)" fill-rule="evenodd"/>`;
    if (hole) {
      svg += `<rect x="${rect.x}" y="${rect.y}" width="${rect.w}" height="${rect.h}" rx="${r}" fill="rgba(255,255,255,0.1)" stroke="rgba(255,255,255,0.95)" stroke-width="1.6"/>`;
      for (const [hx, hy] of [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]) {
        svg += `<circle cx="${rect.x + rect.w * hx}" cy="${rect.y + rect.h * hy}" r="4" fill="#fff" stroke="rgba(0,0,0,0.18)" stroke-width="1"/>`;
      }
    }
    shotSVG.innerHTML = svg;
  }

  // Capture sink glow
  const sink = model.captureSink.at(t);
  sinkLayer.style.display = sink > 0.001 ? "block" : "none";
  if (sink > 0.001) {
    const glowSize = 22 + 76 * sink;
    const centerY = 8 + 2 * sink + glowSize / 2;
    const place = (node, w, h) => Object.assign(node.style, { left: `${cx}px`, top: `${centerY}px`, width: `${w}px`, height: `${h}px` });
    place(sinkGlow, glowSize, glowSize);
    sinkGlow.style.background = `rgba(255,255,255,${0.12 * sink})`;
    sinkGlow.style.filter = `blur(${14 - 6 * sink}px)`;
    const ring = 18 + 54 * sink;
    place(sinkRing, ring, ring);
    sinkRing.style.boxShadow = `inset 0 0 0 1.4px rgba(255,255,255,${0.24 * sink})`;
    sinkRing.style.transform = `translate(-50%, -50%) scale(${1 + 0.14 * sink})`;
    place(sinkBar, 28 + 72 * sink, 8 + 18 * sink);
    sinkBar.style.background = `linear-gradient(rgba(255,255,255,${0.24 * sink}), rgba(255,255,255,0.04))`;
    sinkBar.style.filter = "blur(8px)";
  }

  // Flight (SelectionCaptureFlightView)
  const flight = model.flight.at(t);
  flightLayer.style.display = flight ? "block" : "none";
  if (!flight) return;
  const progress = flightCurve(Math.min(1, (t - flight.start) / 1.08));
  const start = { x: flight.rect.x + flight.rect.w / 2, y: flight.rect.y + flight.rect.h / 2 };
  const end = { x: CX, y: 16 };
  let w, h;
  if (flight.kind === "text") {
    w = clamp(flight.rect.w + 42, 120, 360);
    h = clamp(flight.rect.h + 24, 40, 112);
  } else {
    const fit = Math.min(360 / flight.rect.w, 220 / flight.rect.h, 1);
    w = clamp(flight.rect.w * fit, 120, 360);
    h = clamp(flight.rect.h * fit, 72, 220);
  }
  const radius = clamp(h * 0.28, 12, 18);
  const key = `${flight.kind}:${w}:${h}`;
  if (key !== lastFlightKey) {
    lastFlightKey = key;
    const fontSize = h > 64 ? 13 : 12;
    const content = flight.kind === "text"
      ? `<div class="cb-tile-text" style="padding:${h > 56 ? 12 : 10}px 14px;gap:${h > 56 ? 8 : 0}px">
          <div style="font-size:${fontSize}px;line-height:${(fontSize * 1.193).toFixed(2)}px;font-weight:600;color:rgba(255,255,255,0.96);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${escapeHTML(flight.text)}</div>
          ${h > 56 ? `<div style="display:flex;flex-direction:column;gap:6px"><span class="cb-tile-line" style="width:${Math.max(32, w * 0.82)}px"></span><span class="cb-tile-line" style="width:${Math.max(32, w * 0.56)}px"></span></div>` : ""}
        </div>`
      : shotThumbHTML(w, h, radius);
    flightTile.innerHTML = `<div class="cb-tile-bg" style="border-radius:${radius}px;background:linear-gradient(135deg, rgba(255,255,255,0.14), rgba(255,255,255,0.04)), rgba(0,0,0,0.9);box-shadow:inset 0 0 0 1px rgba(255,255,255,0.16)"></div>${content}<div class="cb-tile-glow" style="position:absolute;inset:0;border-radius:${radius}px"></div>`;
    flightTile.style.width = `${w}px`;
    flightTile.style.height = `${h}px`;
    flightTile.style.borderRadius = `${radius}px`;
    flightTile.style.boxShadow = "0 10px 36px rgba(0,0,0,0.28), 0 0 24px rgba(255,255,255,0.06)";
  }
  const terminal = clamp((progress - 0.76) / 0.24, 0, 1);
  const distance = Math.hypot(end.x - start.x, end.y - start.y);
  const arc = clamp(Math.max(118, distance * 0.24), 118, 240);
  const c1 = { x: start.x + (end.x - start.x) * 0.18, y: start.y - arc };
  const c2 = { x: start.x + (end.x - start.x) * 0.78, y: end.y - arc * 0.58 };
  const u = 1 - progress;
  const bez = (a, b, c, d) => u * u * u * a + 3 * u * u * progress * b + 3 * u * progress * progress * c + progress ** 3 * d;
  const pos = { x: bez(start.x, c1.x, c2.x, end.x), y: bez(start.y, c1.y, c2.y, end.y) };
  const scaleX = Math.max(0.08, 1 + Math.sin(progress * Math.PI) * 0.06 - terminal * 0.56);
  const scaleY = Math.max(0.08, 1 - Math.sin(progress * Math.PI) * 0.05 - terminal * 0.64);
  const rotation = clamp((end.x - start.x) / 240, -1, 1) * (1 - terminal) * 6;
  flightTile.style.left = `${pos.x + 336 - w / 2}px`;
  flightTile.style.top = `${pos.y - h / 2}px`;
  const glow = flightTile.querySelector(".cb-tile-glow");
  glow.style.boxShadow = `inset 0 0 0 1px rgba(255,255,255,${0.18 * (1 - terminal)})`;
  glow.style.filter = "blur(6px)";
  glow.style.opacity = 0.6 - terminal * 0.5;
  flightLayer.style.transform = `rotate(${rotation}deg) scale(${scaleX}, ${scaleY})`;
  flightLayer.style.opacity = Math.max(0.02, 1 - terminal * 0.94);
  flightLayer.style.filter = `blur(${terminal * 16}px) saturate(${1 - terminal * 0.35}) brightness(${1 + 0.04 * (1 - progress)})`;
}

// ---------------------------------------------------------------------------
// Scene: ask a question across everything saved (Explore)

const ASK = {
  caption: L("Ask a question across your saved items", "对存过的资料提问"),
  answerCaption: L("The answer lists the meeting and notes it used", "回答会列出用到的会议和笔记"),
  explore: L("Explore", "探索"),
  library: L("Library", "数据"),
  todo: L("To-do", "待办"),
  roundTable: L("Round Table", "圆桌"),
  record: L("Record", "录音"),
  hint: L("Drop anything to begin", "拖入任何内容开始"),
  emptyTitle: L("No explore history yet", "还没有探索记录"),
  emptyDetail: L("Start an explore chat and the conversation will appear here.", "发起一次探索后，这里会保留你的对话记录。"),
  placeholder: L("Explore something...", "探索点什么……"),
  questionLabel: L("Question", "问题"),
  answerLabel: L("Answer", "回答"),
  sources: L("Sources", "来源"),
  openSource: L("Open Source", "打开原文件"),
  question: L("What did we decide on launch pricing?", "发布定价最后是怎么定的？"),
  thought: L("Looking through the launch sync and the pricing notes…", "正在查看发布同步会和定价调研笔记…"),
  answer: L(
    "Launch pricing is $12 a month or $99 a year, and the annual plan includes the export add-on. The team picked $12 because the pricing research showed $15 lost about a third of trials. Tom will update the pricing page by Thursday.",
    "发布定价定为月付 12 美元、年付 99 美元，年付包含导出功能。选 12 美元是因为定价调研显示，15 美元会流失约三分之一的试用用户。汤姆会在周四前更新定价页。"
  ),
  tags: [L("Pricing", "定价"), L("Meeting", "会议"), L("Launch", "发布")],
  time: stamp(10, 42),
};

const CITATIONS = [
  { kind: L("Text", "文本"), title: L("Q4 launch sync", "Q4 发布同步会"),
    summary: L("Launch pricing set at $12/month or $99/year, with the export add-on on annual plans.", "发布定价定为月付 12 美元、年付 99 美元，年付含导出功能。"),
    excerpt: L("$12 a month, $99 a year", "月付 12 美元、年付 99 美元") },
  { kind: L("Text", "文本"), title: L("Pricing research notes", "定价调研笔记"),
    summary: L("Trial-to-paid conversion drops from 38% at $12 to 25% at $15.", "试用转付费率：12 美元为 38%，15 美元降到 25%。"),
    excerpt: L("$15 converts 25% vs 38% at $12", "15 美元转化 25%，12 美元为 38%") },
];

const settingsButtonHTML = `<span class="cb-settings-button" style="filter:drop-shadow(0 2px 3px rgba(255,255,255,0.08))">${pixelIconSVG("gear", TONES.neutral.glyph, 14)}</span>`;
const backButtonHTML = `<span class="cb-chrome-button">${pixelIconSVG("chevronLeft", "rgba(255,255,255,0.84)", 13)}</span>`;

function hoverView() {
  const button = (icon, label) => `<div class="cb-hover-button"><span class="cb-hover-box"><span style="display:block;width:20px;height:20px;filter:drop-shadow(0 2px 3px ${withAlpha(TONES.neutral.glyph, 0.08)})">${pixelIconSVG(icon, TONES.neutral.glyph, 20)}</span></span><span class="cb-hover-label">${escapeHTML(label)}</span></div>`;
  return contentShell(`
    <div class="cb-hover">
      <div class="cb-hover-buttons">${button("search", ASK.explore)}${button("library", ASK.library)}${button("check", ASK.todo)}${button("sword", ASK.roundTable)}</div>
      <div class="cb-hover-bottom"><span class="cb-record-button"><i></i>${escapeHTML(ASK.record)}</span><span class="cb-spacer"></span><span class="cb-hover-hint">${escapeHTML(ASK.hint)}</span></div>
    </div>`, { chrome: settingsButtonHTML });
}

function spinnerSVG(t) {
  const step = Math.floor(t * 12) % 8;
  let lines = "";
  for (let i = 0; i < 8; i++) {
    const alpha = 0.25 + 0.75 * (((i - step + 8) % 8) / 7);
    const a = (i / 8) * Math.PI * 2;
    lines += `<line x1="${6 + Math.sin(a) * 2.6}" y1="${6 - Math.cos(a) * 2.6}" x2="${6 + Math.sin(a) * 5.2}" y2="${6 - Math.cos(a) * 5.2}" stroke="rgba(255,255,255,${alpha.toFixed(2)})" stroke-width="1.3" stroke-linecap="round"/>`;
  }
  return `<svg class="cb-spinner" viewBox="0 0 12 12">${lines}</svg>`;
}

function composerHTML({ text, focused, trash }, t) {
  const caret = focused && Math.floor(t / 0.53) % 2 === 0 ? `<span class="cb-caret"></span>` : "";
  const field = text ? `${escapeHTML(text)}${caret}` : `${caret}<span class="cb-placeholder">${escapeHTML(ASK.placeholder)}</span>`;
  const trashButton = trash ? `<span class="cb-chrome-button">${pixelIconSVG("trash", rgb(0.95, 0.52, 0.52), 12)}</span>` : "";
  return `<div class="cb-composer">${trashButton}<span class="cb-composer-field">${field}</span><span class="cb-send"><img src="assets/arrow-up.png" alt=""></span></div>`;
}

/** The whole Explore panel; what it shows depends on the scripted conversation state. */
function exploreView() {
  const node = contentShell(`<div class="cb-answer"></div>`);
  const root = node.querySelector(".cb-answer");
  const chrome = node.querySelector(".cb-chrome-row");
  let lastKey = "";
  const update = (t) => {
    const phase = model.askPhase.at(t); // "empty" | "pending" | "ready"
    const draft = model.draft.at(t);
    const answer = model.answerText.at(t);
    const key = `${phase}|${draft}|${answer}|${phase === "empty" ? Math.floor(t / 0.53) % 2 : 0}|${phase === "pending" ? Math.floor(t * 12) % 8 : 0}`;
    if (key === lastKey) return;
    lastKey = key;
    chrome.innerHTML = phase === "empty" ? "" : settingsButtonHTML;
    const header = `<div class="cb-answer-header"><span class="cb-answer-title">${escapeHTML(ASK.explore)}</span><span class="cb-spacer"></span>
      ${phase === "ready" ? `<span class="cb-tag-strip">${ASK.tags.map((tag) => `<span>${escapeHTML(tag)}</span>`).join("")}</span>` : ""}
      ${phase !== "pending" ? backButtonHTML : ""}</div>`;
    let body;
    if (phase === "empty") {
      body = `<div class="cb-card"><span class="cb-empty-title">${escapeHTML(ASK.emptyTitle)}</span><span class="cb-empty-detail">${escapeHTML(ASK.emptyDetail)}</span></div>`;
    } else {
      const label = (text) => `<span class="cb-turn-label">${escapeHTML(text)}</span>`;
      const card = phase === "ready"
        ? `<div class="cb-card cb-turn"><div class="cb-turn-head">${label(ASK.questionLabel)}<span class="cb-turn-time">${escapeHTML(ASK.time)}</span></div>
            <span class="cb-turn-question">${escapeHTML(ASK.question)}</span>${label(ASK.answerLabel)}<span class="cb-turn-answer">${escapeHTML(ASK.answer)}</span></div>`
        : `<div class="cb-card cb-turn">${label(ASK.questionLabel)}<span class="cb-turn-question">${escapeHTML(ASK.question)}</span>
            <span class="cb-answer-label-row">${label(ASK.answerLabel)}${spinnerSVG(t)}</span><span class="cb-turn-answer">${escapeHTML(answer)}</span></div>`;
      const sources = phase === "ready"
        ? `<div class="cb-sources"><span class="cb-sources-label">${escapeHTML(ASK.sources)}</span>${CITATIONS.map((c) => `
            <div class="cb-citation"><div class="cb-citation-head"><span class="cb-citation-kind">${escapeHTML(c.kind)}</span><span class="cb-action-button">${escapeHTML(ASK.openSource)}</span></div>
              <span class="cb-citation-title">${escapeHTML(c.title)}</span><span class="cb-citation-summary">${escapeHTML(c.summary)}</span><span class="cb-citation-excerpt">${escapeHTML(c.excerpt)}</span></div>`).join("")}</div>`
        : "";
      body = `<span class="cb-summary">${escapeHTML(ASK.question)}</span>${card}${sources}`;
    }
    root.innerHTML = `${header}<div class="cb-scroll"><div class="cb-explore">${body}</div></div>${composerHTML({ text: draft, focused: phase === "empty", trash: phase !== "empty" }, t)}`;
  };
  return { node, update };
}

function sceneAsk() {
  register("hover", hoverView(), { w: 420, h: 197 });
  const explore = exploreView();
  register("explore", explore.node, { w: 560, h: 320 }, explore.update);
  model.cursor.set(0, { x: 664, y: 470 }, "step");

  wait(0.5);
  setCaption(ASK.caption);
  moveCursor(450, 18, 0.8);
  expandTo("hover");
  wait(0.7);
  render(clock + 1);
  const exploreButton = stageRect(CONTENT.hover.querySelector(".cb-hover-box"));
  moveCursor(exploreButton.x + exploreButton.w / 2, exploreButton.y + exploreButton.h / 2, 0.55);
  click();
  expandTo("explore", { w: 560, h: 320 });
  wait(0.6);
  moveCursor(744, 520, 0.6);

  for (const character of ASK.question) {
    model.draft.set(clock, model.draft.at(clock) + character, "step");
    wait(LANG === "zh" ? 0.11 : 0.055);
  }
  wait(0.4);
  pressKeys(["↩"], 0.35);

  // Submitted: the notch tucks away while the model reads, thinking shown on the rail.
  model.askPhase.set(clock, "pending", "step");
  collapse({ withIndicator: true });
  showIndicator("recognizing");
  model.railText.set(clock, "", "step");
  railShow(LANG === "zh" ? "正在思考中…" : "Thinking…", "recognizing");
  setCaption(ASK.answerCaption);
  let thought = "";
  for (const character of ASK.thought) {
    thought += character;
    model.railText.set(clock, condensed(thought), "step");
    wait(0.03);
  }
  wait(0.5);

  // The answer streams in; the panel opens on the first words and grows with them.
  let height = 0;
  let first = true;
  const grow = () => {
    explore.update(clock + 0.0001);
    const measured = Math.min(640, Math.max(320, measureContent("explore", 560)));
    if (measured !== height) {
      if (first) {
        railHide();
        hideIndicator();
        expandTo("explore", { w: 560, h: measured });
        first = false;
      } else {
        resizePanel(measured);
      }
      height = measured;
    }
  };
  let streamed = "";
  for (const character of ASK.answer) {
    streamed += character;
    model.answerText.set(clock, streamed, "step");
    grow();
    wait(LANG === "zh" ? 0.045 : 0.02);
  }
  model.askPhase.set(clock, "ready", "step");
  model.draft.set(clock, "", "step");
  height = 0;
  explore.update(clock + 0.0001);
  resizePanel(Math.min(640, Math.max(340, measureContent("explore", 560))));
  wait(4);
  return clock;
}

// ---------------------------------------------------------------------------
// Scene: a recorded meeting turns into to-dos

const MEET = {
  openCaption: L("Open a recorded meeting", "打开一场录过的会议"),
  addCaption: L("Add the action items that are yours", "把属于你的行动项加入待办"),
  todoCaption: L("Accepted items appear in To-do", "确认的事项出现在待办里"),
  structured: L("Structured data", "具体信息"),
  transcript: L("Transcript", "转写文本"),
  actions: L("Action items to confirm", "待确认行动项"),
  snippets: L("Key snippets", "关键片段"),
  dismiss: L("Dismiss", "忽略"),
  add: L("Add to-do", "加入待办"),
  owner: L("Owner: ", "负责人："),
  due: L("Due: ", "时间："),
  text: L(
    "Mia: Let's lock launch pricing today.\nTom: The data says $12 is the sweet spot. At $15 we lose a third of trials.\nMia: Agreed. $12 a month, $99 a year, and annual gets the export add-on.\nTom: I'll update the pricing page by Thursday and send it to Lena.",
    "米娅：今天把发布定价定下来。\n汤姆：数据看 12 美元最合适，定 15 美元会流失三分之一的试用。\n米娅：同意。月付 12 美元、年付 99 美元，年付送导出功能。\n汤姆：我周四前改好定价页，发给李娜。"
  ),
  topic: L("Launch pricing", "发布定价"),
  snippet: L("$12 a month, $99 a year", "月付 12 美元、年付 99 美元"),
  todoTitle: L("To-do", "待办"),
  open: L("Open", "未完成"),
  completed: L("Completed", "已完成"),
  all: L("All", "全部"),
  addTodo: L("Add", "新增"),
  from: L("From", "来自"),
  why: L("Why", "原因"),
};

const ACTION_ITEMS = [
  { id: "DDEE99AE-F5B5-46EE-A19F-F6A3196D0EB4", title: L("Update the pricing page to $12 / $99 and send it to Lena", "把定价页改成 12 / 99 美元并发给李娜"),
    owner: L("Tom", "汤姆"), dueText: L("Thursday", "周四"), reason: L("The new pricing has to be live before launch.", "新定价要在发布前上线。"),
    evidence: L("I'll update the pricing page by Thursday and send it to Lena.", "我周四前改好定价页，发给李娜。"), quadrant: "important_urgent" },
  { id: "DE770CF5-9967-4E44-B8A5-8AA3A1E32A3E", title: L("Add the export add-on to the annual plan", "给年付套餐加上导出功能"),
    owner: L("Mia", "米娅"), dueText: L("Next week", "下周"), reason: L("Agreed as the annual-plan incentive.", "会上定为年付的附加权益。"),
    evidence: L("Annual gets the export add-on.", "年付送导出功能。"), quadrant: "important_not_urgent" },
];

// The meeting record keeps its action items as JSON in structured data, and the detail view shows it as is.
const actionItemsJSON = "[" + ACTION_ITEMS.map((item) =>
  `{"dueText":"${item.dueText}","id":"${item.id}","evidence":"${item.evidence}","suggestedQuadrant":"${item.quadrant}","owner":"${item.owner}","status":"pending","reason":"${item.reason}","title":"${item.title.replace(/\//g, "\\/")}"}`
).join(",") + "]";

const QUADRANT_COLOR = { important_urgent: [1.0, 0.47, 0.42], important_not_urgent: [0.42, 0.78, 1.0], urgent_not_important: [1.0, 0.76, 0.32], not_important_not_urgent: [0.66, 0.68, 0.72] };
const QUADRANT_SHORT = { important_urgent: "Q1", important_not_urgent: "Q2", urgent_not_important: "Q3", not_important_not_urgent: "Q4" };

function meetingDetailView(record) {
  const kind = KIND[record.kind];
  const node = contentShell(`
    <div class="cb-detail">
      <div class="cb-header"><span class="cb-title">${escapeHTML(DETAIL.title)}</span><span class="cb-spacer"></span>${backButtonHTML}</div>
      <div class="cb-detail-body">
        <div class="cb-detail-scroll"><div class="cb-detail-cards"></div></div>
        <div class="cb-actionbar">${tile("folder", DETAIL.reveal)}${tile("open", DETAIL.open)}${tile("sword", DETAIL.discuss)}${tile("trash", DETAIL.delete, true)}</div>
      </div>
    </div>`);
  const cards = node.querySelector(".cb-detail-cards");
  const section = (title, inner, extra = "") => `<div class="cb-glass cb-section"${extra}><span class="cb-section-title">${escapeHTML(title)}</span>${inner}</div>`;
  const fixed = `
    <div class="cb-glass cb-hero">${previewHTML(record, 128, 26, 32)}
      <div class="cb-hero-text">
        <div class="cb-pills">${pill(kind.label, kind.tone)}${pill(STATUS_READY, "success", "check")}</div>
        <div class="cb-hero-title">${escapeHTML(record.title)}</div>
        <div class="cb-hero-summary">${escapeHTML(record.summary)}</div>
        <div class="cb-tags">${record.tags.map((tag) => `<span class="cb-tag">${escapeHTML(tag)}</span>`).join("")}</div>
        <div class="cb-facts">
          <div class="cb-fact"><span class="cb-fact-label">${escapeHTML(DETAIL.updated)}</span><span class="cb-fact-value">${escapeHTML(record.time)}</span></div>
          <div class="cb-fact"><span class="cb-fact-label">${escapeHTML(DETAIL.fileName)}</span><span class="cb-fact-value">${escapeHTML(record.fileName)}</span></div>
        </div>
      </div>
    </div>
    ${section(DETAIL.metadata, `<div class="cb-values">${valueRow(DETAIL.fileName, record.fileName)}${valueRow(DETAIL.type, kind.label)}${valueRow(DETAIL.scene, record.scene)}${valueRow(DETAIL.purpose, record.purpose)}${valueRow(DETAIL.parse, STATUS_READY)}${valueRow(DETAIL.updated, record.time)}${valueRow(DETAIL.tags, record.tags.join(" · "))}</div>`)}
    ${section(MEET.structured, `<div class="cb-values">
      <div class="cb-value"><span class="cb-value-label">meetingActionItems</span><span class="cb-value-text cb-wrap">${escapeHTML(actionItemsJSON)}</span></div>
      ${valueRow("meetingDurationSeconds", "1860")}${valueRow("meetingParticipantCount", "3")}${valueRow("meetingSource", "notch-meeting")}${valueRow("meetingTopic", MEET.topic)}</div>`)}
    ${section(MEET.transcript, `<div class="cb-transcript">${escapeHTML(MEET.text)}</div>`)}`;
  let lastAccepted = -1;
  const build = (accepted) => {
    const pending = ACTION_ITEMS.slice(accepted);
    const actionCard = pending.length
      ? section(MEET.actions, `<div class="cb-actions">${pending.map((item) => `
          <div class="cb-action-item"><span class="cb-action-title">${escapeHTML(item.title)}</span>
            <span class="cb-action-meta">${escapeHTML(`${MEET.owner}${item.owner} · ${MEET.due}${item.dueText}`)}</span>
            <span class="cb-action-reason">${escapeHTML(item.reason)}</span>
            <span class="cb-action-evidence">${escapeHTML(`“${item.evidence}”`)}</span>
            <div class="cb-action-buttons"><span class="cb-decision">${escapeHTML(MEET.dismiss)}</span><span class="cb-decision cb-emphasized">${escapeHTML(MEET.add)}</span></div>
          </div>`).join("")}</div>`, ' data-actions="1"')
      : "";
    cards.innerHTML = fixed + actionCard + section(MEET.snippets, `<div class="cb-snippet">${escapeHTML(MEET.snippet)}</div>`);
  };
  const scroller = node.querySelector(".cb-detail-scroll");
  const update = (t) => {
    const accepted = model.accepted.at(t);
    if (accepted !== lastAccepted) {
      lastAccepted = accepted;
      build(accepted);
    }
    const maxScroll = Math.max(0, cards.offsetHeight - scroller.clientHeight);
    cards.style.transform = `translateY(${-Math.min(model.scroll.at(t), maxScroll)}px)`;
  };
  return { node, update, cards, scroller };
}

function todoListView(items = ACTION_ITEMS) {
  const node = contentShell(`<div class="cb-todos"></div>`);
  const root = node.querySelector(".cb-todos");
  const color = (q, a = 1) => rgb(...QUADRANT_COLOR[q], a);
  const filters = `<div class="cb-todo-filters">
      <div class="cb-status-filters"><span class="cb-status-filter cb-selected">${escapeHTML(MEET.open)}</span><span class="cb-status-filter">${escapeHTML(MEET.completed)}</span></div>
      <div class="cb-quadrant-filters"><span class="cb-quadrant-filter" style="background:rgba(255,255,255,0.74);color:rgba(0,0,0,0.82)">${escapeHTML(MEET.all)}</span>
        ${Object.keys(QUADRANT_SHORT).map((q) => `<span class="cb-quadrant-filter" style="background:${color(q, 0.1)};box-shadow:inset 0 0 0 1px ${color(q, 0.24)};color:${color(q)}">${QUADRANT_SHORT[q]}</span>`).join("")}</div>
    </div>`;
  const rows = items.map((item) => `
    <div class="cb-todo"><span class="cb-checkbox"></span>
      <div class="cb-todo-main"><div class="cb-todo-text">
        <span class="cb-todo-title">${escapeHTML(item.title)}</span>
        <span class="cb-todo-detail">${escapeHTML(item.reason)}</span>
        <span class="cb-todo-source">${pixelIconSVG("library", "rgba(255,255,255,0.42)", 9)}${escapeHTML(`${MEET.from} ${RECORDS.meeting.title}`)}</span>
        <span class="cb-todo-why">${escapeHTML(`${MEET.why}: ${item.reason}`)}</span>
      </div><span class="cb-quadrant-pill" style="background:${color(item.quadrant, 0.1)};box-shadow:inset 0 0 0 1px ${color(item.quadrant, 0.22)};color:${color(item.quadrant)}">${QUADRANT_SHORT[item.quadrant]}</span></div>
    </div>`).join("");
  root.innerHTML = `<div class="cb-header" style="gap:10px"><span class="cb-title">${escapeHTML(MEET.todoTitle)}</span><span class="cb-count">${pixelTextHTML(String(items.length), TONES.neutral.glyph, 9)}</span><span class="cb-spacer"></span>${backButtonHTML}</div>
    ${filters}<div class="cb-todo-list">${rows}</div><div class="cb-todo-footer">${tile("check", MEET.addTodo)}</div>`;
  return node;
}

function sceneMeeting() {
  register("hover", hoverView(), { w: 420, h: 197 });
  register("library", libraryView([RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  const detail = meetingDetailView(RECORDS.meeting);
  register("detail", detail.node, { w: 520, h: 548 }, detail.update);
  register("todos", todoListView(), { w: 520, h: 448 });
  model.cursor.set(0, { x: 664, y: 470 }, "step");
  const centerOf = (node) => { const r = stageRect(node); return { x: r.x + r.w / 2, y: r.y + r.h / 2 }; };

  wait(0.5);
  setCaption(MEET.openCaption);
  moveCursor(450, 18, 0.8);
  expandTo("hover");
  wait(0.7);
  render(clock + 1);
  let target = centerOf(CONTENT.hover.querySelectorAll(".cb-hover-box")[1]);
  moveCursor(target.x, target.y, 0.55);
  click();
  expandTo("library");
  wait(1.0);
  render(clock + 1);
  target = centerOf(CONTENT.library.querySelector(".cb-row"));
  moveCursor(target.x, target.y, 0.7);
  click();
  expandTo("detail");
  wait(1.1);
  moveCursor(660, 330, 0.5);

  // Scroll down to the suggested action items.
  render(clock + 1);
  detail.update(clock + 1);
  const actionsCard = detail.cards.querySelector("[data-actions]");
  const scrollTarget = actionsCard.offsetTop - 8;
  setCaption(MEET.addCaption);
  model.scroll.set(clock, scrollTarget, "ease", 1.3);
  wait(1.6);

  for (let i = 0; i < ACTION_ITEMS.length; i++) {
    render(clock);
    detail.update(clock);
    const button = detail.cards.querySelector(".cb-decision.cb-emphasized");
    target = centerOf(button);
    moveCursor(target.x, target.y, 0.6);
    click();
    wait(0.35);
    model.accepted.set(clock, i + 1, "step");
    wait(0.9);
  }

  setCaption(MEET.todoCaption);
  collapse();
  moveCursor(664, 420, 0.5);
  wait(0.4);
  moveCursor(450, 18, 0.7);
  expandTo("hover");
  wait(0.7);
  render(clock + 1);
  target = centerOf(CONTENT.hover.querySelectorAll(".cb-hover-box")[2]);
  moveCursor(target.x, target.y, 0.55);
  click();
  expandTo("todos");
  moveCursor(744, 520, 0.8);
  wait(3.2);
  return clock;
}

// ---------------------------------------------------------------------------
// Scene: bring a record to the 12 Knights round table.
// The window holds the real round-table page (an isolated demo instance), so this
// scene plays in real time and record-live.mjs drives the page inside it.

const RT = {
  caption: L("Bring the meeting to the round table", "把会议带到圆桌"),
  discussCaption: L("The AI knights discuss it with the record in hand", "AI 骑士带着这份资料一起讨论"),
  calling: L("Opening…", "召集中…"),
  url: params.get("rt") || "http://127.0.0.1:3799/",
  frame: { x: 30, y: 74, w: 780, h: 540 },
};

const rtWindow = el("div", "cb-rt-window");
Object.assign(rtWindow.style, { left: `${RT.frame.x}px`, top: `${RT.frame.y}px`, width: `${RT.frame.w}px`, height: `${RT.frame.h}px`, display: "none" });

function sceneRoundTable() {
  const iframe = el("iframe");
  iframe.src = RT.url;
  rtWindow.appendChild(iframe);
  stage.insertBefore(rtWindow, notchSVG);
  const detail = meetingDetailView(RECORDS.meeting);
  register("detail", detail.node, { w: 520, h: 548 }, (t) => {
    detail.update(t);
    const discuss = detail.node.querySelectorAll(".cb-tile")[2];
    const busy = model.discussing.at(t);
    if (discuss.dataset.busy !== String(busy)) {
      discuss.dataset.busy = String(busy);
      discuss.innerHTML = `${pixelIconSVG(busy ? "hourglass" : "sword", "rgba(255,255,255,0.86)", 14)}<span>${escapeHTML(busy ? RT.calling : DETAIL.discuss)}</span>`;
    }
  });
  model.cursor.set(0, { x: 690, y: 640 }, "step");
  expandTo("detail");
  model.surface.set(0, model.surface.at(0.001), "step");
  model.composite.set(0, model.composite.at(0.001), "step");

  wait(0.8);
  setCaption(RT.caption);
  render(clock + 1);
  const tileRect = stageRect(detail.node.querySelectorAll(".cb-tile")[2]);
  moveCursor(tileRect.x + tileRect.w / 2, tileRect.y + tileRect.h / 2, 0.8);
  click();
  model.discussing.set(clock, 1, "step");
  MARKERS.discussAt = clock;
  wait(0.5);
  model.discussing.set(clock, 0, "step");
  collapse();
  model.rtWindow.set(clock, 0, "step");
  model.rtWindow.set(clock, 1, "easeOut", 0.22);
  setCaption(RT.discussCaption);
  moveCursor(560, 600, 0.7);
  MARKERS.typeAt = clock + 1.0;
  wait(11.5);
  return clock;
}

function renderRoundTable(t) {
  const p = model.rtWindow.at(t);
  rtWindow.style.display = p > 0.001 ? "block" : "none";
  rtWindow.style.opacity = p;
  rtWindow.style.transform = `translateY(${-28 * (1 - p)}px)`;
}

// ---------------------------------------------------------------------------
// Scene: an AI assistant uses casebase through casebase-mcp.
// Tool names and results are what casebase-mcp returns for the demo library.

const MCP = {
  caption: L("Your AI tools can use casebase too", "你的 AI 工具也能用 casebase"),
  todoCaption: L("The new to-do is already in casebase", "新待办已经在 casebase 里了"),
  title: L("Terminal — MCP client", "终端 — MCP 客户端"),
  ask: L("What did we decide on launch pricing? Add the launch-page change as a to-do.", "发布定价最后怎么定的？顺便把发布页要改的地方记成待办"),
  steps: [
    { tool: "casebase_search_records", arg: L('query: "launch pricing"', 'query: "发布定价"'), result: L("2 records: Pricing research notes, Q4 launch sync", "2 条记录：定价调研笔记、Q4 发布同步会") },
    { tool: "casebase_get_record", arg: 'id: "F409C122-E769-…"', result: L("Q4 launch sync · $12/month or $99/year, export add-on on annual", "Q4 发布同步会 · 月付 12 美元、年付 99 美元，年付含导出功能") },
    { say: L("Launch pricing is $12 a month or $99 a year, with the export add-on on annual plans. At $15, trial-to-paid fell from 38% to 25%.", "发布定价是月付 12 美元、年付 99 美元，年付送导出功能。依据是定价调研：15 美元时试用转付费率从 38% 降到 25%。") },
    { tool: "casebase_create_todo", arg: L('title: "Put “export included with annual” on the launch page"', 'title: "发布页第一屏写上「年付送导出」"'), result: L("Created · Q1 · from Q4 launch sync", "已创建待办 · Q1 · 来源：Q4 发布同步会") },
    { say: L("Added it to your casebase to-dos.", "已经加到 casebase 的待办里了。") },
  ],
  newTodo: { title: L('Put “export included with annual” on the launch page', "发布页第一屏写上「年付送导出」"),
    reason: L("Suggested in the launch sync to keep annual plans attractive.", "会上建议，让年付更有吸引力。"), quadrant: "important_urgent" },
};

const term = el("div", "cb-term", `<div class="cb-term-bar"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i><span class="cb-term-title"></span></div><div class="cb-term-body"></div>`);
Object.assign(term.style, { left: "60px", top: "120px", width: "720px", height: "430px", display: "none" });

function sceneMCP() {
  stage.insertBefore(term, notchSVG);
  term.querySelector(".cb-term-title").textContent = MCP.title;
  register("hover", hoverView(), { w: 420, h: 197 });
  const items = [MCP.newTodo, ...ACTION_ITEMS];
  register("todos", todoListView(items), { w: 520, h: 540 });
  model.term.set(0, 1, "step");
  model.cursor.set(0, { x: 700, y: 610 }, "step");

  wait(0.5);
  setCaption(MCP.caption);
  for (const character of MCP.ask) {
    model.termTyped.set(clock, model.termTyped.at(clock) + character, "step");
    wait(LANG === "zh" ? 0.06 : 0.03);
  }
  wait(0.4);
  model.termLines.set(clock, 0, "step");
  for (let i = 0; i < MCP.steps.length; i++) {
    model.termBusy.set(clock, 1, "step");
    wait(MCP.steps[i].tool ? 0.9 : 0.6);
    model.termBusy.set(clock, 0, "step");
    model.termLines.set(clock, i + 1, "step");
    wait(0.5);
  }
  wait(0.8);

  setCaption(MCP.todoCaption);
  moveCursor(450, 18, 0.8);
  expandTo("hover");
  wait(0.7);
  render(clock + 1);
  const box = stageRect(CONTENT.hover.querySelectorAll(".cb-hover-box")[2]);
  moveCursor(box.x + box.w / 2, box.y + box.h / 2, 0.55);
  click();
  expandTo("todos");
  moveCursor(744, 600, 0.8);
  wait(3.2);
  return clock;
}

function renderTerminal(t) {
  term.style.display = model.term.at(t) ? "block" : "none";
  if (term.style.display === "none") return;
  const typed = model.termTyped.at(t);
  const shown = model.termLines.at(t);
  const busy = model.termBusy.at(t);
  const spinner = "✶✸✹✺✹✸"[Math.floor(t * 8) % 6];
  let html = `<span class="p">&gt; </span><span class="user">${escapeHTML(typed)}</span>${shown < 0 && Math.floor(t / 0.53) % 2 === 0 ? "▌" : ""}\n`;
  MCP.steps.slice(0, Math.max(0, shown)).forEach((step) => {
    html += "\n";
    if (step.tool) html += `<span class="dot">⏺</span> <span class="tool">casebase · ${step.tool}</span><span class="arg">(${escapeHTML(step.arg)})</span>\n  <span class="res">⎿  ${escapeHTML(step.result)}</span>\n`;
    else html += `<span class="dot">⏺</span> <span class="say">${escapeHTML(step.say)}</span>\n`;
  });
  if (busy) html += `\n<span class="spin">${spinner} ${L("Working…", "处理中…")}</span>\n`;
  term.querySelector(".cb-term-body").innerHTML = html;
}

// ---------------------------------------------------------------------------
// Live notch for a web page: hover to open the menu, click through to panels.
// The host page sends hover state; the frame reports the notch's rectangle back.

let liveStart = 0;
const liveNow = () => (performance.now() - liveStart) / 1000;


const LIVE_TRACKS = () => [
  model.indicator, model.indicatorOpacity, model.railText, model.railState, model.rail,
  model.surface, model.shadow, model.composite, model.compositeOpacity, model.content,
  model.captureSink, model.feedbackScale, model.askPhase, model.draft, model.answerText,
  ...Object.values(model.contentOpacity),
];

/** A capture lands in the notch: glow, then the rail shows it being read and saved. */
function liveIngest(thought) {
  LIVE_TRACKS().forEach((track) => track.clearAfter(clock));
  if (model.content.at(clock) !== null) collapse();
  intakePulse();
  model.surface.set(clock, { w: NOTCH.w + LEADING_EXTENSION, h: NOTCH.h, r: 8, ox: -LEADING_EXTENSION / 2 });
  showIndicator("recognizing");
  railShow(condensed(thought), "recognizing");
  model.indicator.set(clock + 1.1, "success", "step");
  model.railState.set(clock + 1.1, "success", "step");
  model.railText.set(clock + 1.1, T.saved, "step");
  // The result rail stays for 2 s (taskRailResultDurationNs), then the notch tucks back in.
  const now = clock;
  clock = now + 3.1;
  railHide();
  hideIndicator();
  clock = now;
}

/** Open Explore, type the question, stream the answer with its sources. */
function liveAsk(explore) {
  LIVE_TRACKS().forEach((track) => track.clearAfter(clock));
  railHide();
  hideIndicator();
  model.askPhase.clearAfter(0);
  model.draft.clearAfter(0);
  model.answerText.clearAfter(0);
  model.askPhase.set(clock, "empty", "step");
  model.draft.set(clock, "", "step");
  model.answerText.set(clock, "", "step");
  expandTo("explore", { w: 560, h: 320 });
  wait(0.5);
  for (const character of ASK.question) {
    model.draft.set(clock, model.draft.at(clock) + character, "step");
    wait(LANG === "zh" ? 0.09 : 0.045);
  }
  wait(0.35);
  model.askPhase.set(clock, "pending", "step");
  let height = 320;
  let streamed = "";
  for (const character of ASK.answer) {
    streamed += character;
    model.answerText.set(clock, streamed, "step");
    explore.update(clock + 0.0001);
    const measured = Math.min(640, Math.max(320, measureContent("explore", 560)));
    if (measured !== height) { resizePanel(measured); height = measured; }
    wait(LANG === "zh" ? 0.035 : 0.015);
  }
  model.askPhase.set(clock, "ready", "step");
  model.draft.set(clock, "", "step");
  explore.update(clock + 0.0001);
  resizePanel(Math.min(640, Math.max(340, measureContent("explore", 560))));
}

function liveReset() {
  LIVE_TRACKS().forEach((track) => track.clearAfter(clock));
  railHide();
  hideIndicator();
  if (model.content.at(clock) !== null) collapse();
}

function sceneLive() {
  register("hover", hoverView(), { w: 420, h: 197 });
  register("dropTarget", dropZone, { w: 520, h: 220 });
  register("library", libraryView([RECORDS.report, RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  const explore = exploreView();
  register("explore", explore.node, { w: 560, h: 320 }, explore.update);
  register("todos", todoListView(), { w: 520, h: 448 });
  model.cursor.set(0, { x: -100, y: -100 }, "step");
  liveStart = performance.now();

  const at = (fn) => { clock = liveNow(); fn(); };
  // Opening a panel cancels anything still scheduled from an earlier capture.
  const open = (state) => at(() => {
    LIVE_TRACKS().forEach((track) => track.clearAfter(clock));
    if (model.indicator.at(clock)) { railHide(); hideIndicator(); }
    expandTo(state);
  });
  const close = () => at(() => { if (model.content.at(clock) !== null) collapse(); });
  window.addEventListener("message", (event) => {
    if (!event.data || event.data.type !== "cb-live") return;
    if (event.data.hover && model.content.at(liveNow()) === null) open("hover");
    if (event.data.hover === false) close();
    if (event.data.ingest) at(() => liveIngest(event.data.ingest));
    if (event.data.ask) at(() => liveAsk(explore));
    if (event.data.reset) at(() => liveReset());
    if (event.data.dropTarget === true && model.content.at(liveNow()) !== "dropTarget") open("dropTarget");
    if (event.data.dropTarget === false && model.content.at(liveNow()) === "dropTarget") close();
  });
  const targets = [["explore", 0], ["library", 1], ["todos", 2]];
  for (const [state, index] of targets) {
    CONTENT.hover.querySelectorAll(".cb-hover-button")[index].addEventListener("click", () => open(state));
  }
  for (const name of ["library", "explore", "todos"]) {
    CONTENT[name].addEventListener("click", (event) => {
      if (event.target.closest(".cb-chrome-button")) open("hover");
    });
  }
  document.addEventListener("mousemove", (event) => {
    const r = window.casebaseDemo.notchRect();
    const inside = event.clientX >= r.x - 16 && event.clientX <= r.x + r.w + 16 && event.clientY <= r.h + 16;
    if (!inside) {
      close();
      window.parent.postMessage({ type: "cb-live-leave" }, "*");
    }
  });
  return Infinity;
}

// Static views for comparing against the app's own rendering.
function sceneCheck() {
  const view = params.get("view");
  if (view === "detail-meeting") register("detail", detailView(RECORDS.meeting), { w: 520, h: 548 });
  if (view === "library") register("library", libraryView([RECORDS.meeting, RECORDS.pricing, RECORDS.interview, RECORDS.contract]), { w: 520, h: 456 });
  model.cursor.set(0, { x: -100, y: -100 }, "step");
  expandTo(Object.keys(CONTENT)[0]);
  return 2;
}

const SCENES = { drop: sceneDrop, text: sceneText, shot: sceneShot, ask: sceneAsk, meeting: sceneMeeting, roundtable: sceneRoundTable, mcp: sceneMCP, live: sceneLive, check: sceneCheck };
const MARKERS = {};
const sceneName = params.get("scene") || "drop";
const sceneQuery = location.search;
await document.fonts.ready;
const duration = SCENES[sceneName]();

window.casebaseDemo = {
  duration,
  markers: MARKERS,
  notchRect() {
    const surface = model.surface.at(LIVE ? liveNow() : 0);
    return { x: CX + surface.ox - surface.w / 2, y: 0, w: surface.w, h: surface.h };
  },
  seek(t) { render(t); },
};

if (LIVE) {
  document.documentElement.classList.add("cb-embed");
  let last = "";
  const loop = () => {
    render(liveNow());
    const r = window.casebaseDemo.notchRect();
    const key = [r.x, r.w, r.h].map((v) => Math.round(v)).join(",");
    if (key !== last) {
      last = key;
      window.parent.postMessage({ type: "cb-live-rect", rect: r }, "*");
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
} else if (params.has("live")) {
  // Real-time playback for scenes with live content; the recorder reads elapsed().
  let start = null;
  window.casebaseDemo.begin = () => { start = performance.now(); };
  window.casebaseDemo.elapsed = () => (start === null ? 0 : (performance.now() - start) / 1000);
  const loop = () => {
    render(Math.min(duration, window.casebaseDemo.elapsed()));
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
} else if (params.has("embed")) {
  // Embedded in a page: scale to the frame's width, and play only while the host says it's visible.
  document.documentElement.classList.add("cb-embed");
  // Optional crop "x,y,w,h" (stage points): show only that region, scaled to the frame.
  const crop = (params.get("crop") || `0,0,840,${STAGE_HEIGHT}`).split(",").map(Number);
  const fit = () => {
    const scale = window.innerWidth / crop[2];
    stage.style.transformOrigin = "0 0";
    stage.style.transform = `scale(${scale}) translate(${-crop[0]}px, ${-crop[1]}px)`;
  };
  fit();
  window.addEventListener("resize", fit);
  // The host sends start (from the top), pause (hold this frame) and resume.
  // Before the first start, the scene's last frame stands in as a poster.
  const poster = Math.max(0, duration - 0.6);
  let start = null;
  let held = poster;
  const current = () => (start === null ? held : ((performance.now() - start) / 1000) % duration);
  window.addEventListener("message", (event) => {
    if (!event.data || event.data.type !== "cb-demo") return;
    const action = event.data.action || (event.data.play ? "start" : "pause");
    if (action === "start") start = performance.now();
    else if (action === "pause" && start !== null) { held = current(); start = null; }
    else if (action === "resume" && start === null) start = performance.now() - held * 1000;
  });
  const loop = () => {
    render(current());
    requestAnimationFrame(loop);
  };
  render(poster);
  requestAnimationFrame(loop);
  // Tell the host page we're listening, so it can send the current play state.
  window.parent.postMessage({ type: "cb-demo-ready" }, "*");
} else if (!params.has("record")) {
  const start = performance.now();
  const loop = () => {
    render(((performance.now() - start) / 1000) % duration);
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
} else {
  render(0);
}
