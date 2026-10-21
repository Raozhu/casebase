// Deterministic animation engine for the casebase demos.
// Every value is a pure function of time, so a page can play in real time
// and a recorder can seek to any frame and get the same picture.

import { PIXEL_PATTERNS, SVG_SYMBOLS, PIXEL_FONT } from "./icons.js";

// SwiftUI `.interactiveSpring(duration: 0.314)`: a spring with no bounce (critically damped).
export const NOTCH_RESPONSE = 0.314;
export function springProgress(t, response = NOTCH_RESPONSE) {
  if (t <= 0) return 0;
  const w = (2 * Math.PI) / response;
  return 1 - (1 + w * t) * Math.exp(-w * t);
}

/** SwiftUI `.spring(response:dampingFraction:)`, including the underdamped (bouncy) case. */
export function dampedSpring(t, response, damping) {
  if (t <= 0) return 0;
  const w0 = (2 * Math.PI) / response;
  if (damping >= 1) return 1 - (1 + w0 * t) * Math.exp(-w0 * t);
  const wd = w0 * Math.sqrt(1 - damping * damping);
  return 1 - Math.exp(-damping * w0 * t) * (Math.cos(wd * t) + ((damping * w0) / wd) * Math.sin(wd * t));
}

/** CSS / SwiftUI timing curve `cubic-bezier(x1, y1, x2, y2)`. */
export function bezierTiming(x1, y1, x2, y2) {
  const sample = (a, b, t) => 3 * a * (1 - t) * (1 - t) * t + 3 * b * (1 - t) * t * t + t * t * t;
  return (x) => {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let lo = 0, hi = 1, t = x;
    for (let i = 0; i < 40; i++) {
      t = (lo + hi) / 2;
      if (sample(x1, x2, t) < x) lo = t; else hi = t;
    }
    return sample(y1, y2, t);
  };
}

const easeOutCurve = bezierTiming(0, 0, 0.58, 1);

export function easeInOut(t) {
  t = Math.min(1, Math.max(0, t));
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

function mix(a, b, p) {
  if (typeof a === "number" && typeof b === "number") return a + (b - a) * p;
  if (a && b && typeof a === "object") {
    const out = {};
    for (const key of Object.keys(b)) out[key] = mix(a[key] ?? b[key], b[key], p);
    return out;
  }
  return p < 1 ? (p > 0 ? b : a) : b;
}

/** A value that changes at scripted times, with a curve per change. */
export class Track {
  constructor(initial) {
    this.segments = [{ t: -Infinity, from: initial, to: initial, curve: "step", duration: 0 }];
  }

  set(t, to, curve = "spring", duration = NOTCH_RESPONSE) {
    const from = this.at(t);
    this.segments.push({ t, from, to, curve, duration });
    this.segments.sort((a, b) => a.t - b.t);
  }

  segmentAt(t) {
    let current = this.segments[0];
    for (const segment of this.segments) {
      if (segment.t <= t) current = segment;
      else break;
    }
    return current;
  }

  at(t) {
    const s = this.segmentAt(t);
    const elapsed = t - s.t;
    let p;
    switch (s.curve) {
      case "step": p = 1; break;
      case "spring": p = springProgress(elapsed, s.duration); break;
      case "bouncy": p = dampedSpring(elapsed, s.duration[0], s.duration[1]); break;
      case "easeOut": p = easeOutCurve(elapsed / s.duration); break;
      case "ease": p = easeInOut(elapsed / s.duration); break;
      case "linear": p = Math.min(1, elapsed / s.duration); break;
      default: p = 1;
    }
    return typeof s.to === "string" || typeof s.to === "boolean" || s.to === null ? (p > 0 || s.curve === "step" ? s.to : s.from) : mix(s.from, s.to, p);
  }

  /** Drops changes scheduled after t, so a new interaction can take over. */
  clearAfter(t) {
    this.segments = this.segments.filter((segment) => segment.t <= t);
  }

  /** Time since the value last changed, for one-shot animations keyed to a change. */
  since(t) {
    return t - this.segmentAt(t).t;
  }
}

// ---------------------------------------------------------------------------
// Pixel art, drawn from the same data as the app (icons.js is generated).

const SVG_NS = "http://www.w3.org/2000/svg";

/** NotchPixelGlyphView: square cells, each pixel inset by 0.8 with a small corner. */
export function pixelGlyphSVG(pattern, color, size) {
  const rows = pattern.length;
  const cols = pattern[0].length;
  const cell = Math.floor(Math.min(size / cols, size / rows));
  const ox = (size - cols * cell) / 2;
  const oy = (size - rows * cell) / 2;
  const px = Math.max(1, cell - 0.8);
  const r = Math.min(1.2, px * 0.22);
  let rects = "";
  pattern.forEach((row, y) => {
    [...row].forEach((c, x) => {
      if (c === "1") rects += `<rect x="${ox + x * cell}" y="${oy + y * cell}" width="${px}" height="${px}" rx="${r}"/>`;
    });
  });
  return `<svg xmlns="${SVG_NS}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" fill="${color}">${rects}</svg>`;
}

/** NotchPixelIconView: an SVG symbol on a 24-unit grid when one exists, else the pixel pattern. */
export function pixelIconSVG(name, color, size) {
  const symbol = SVG_SYMBOLS[name];
  if (symbol) {
    const paint = symbol.stroke
      ? `fill="none" stroke="${color}" stroke-width="${symbol.stroke}" stroke-linecap="${symbol.cap === "square" ? "square" : "butt"}" stroke-linejoin="miter"`
      : `fill="${color}"`;
    return `<svg xmlns="${SVG_NS}" width="${size}" height="${size}" viewBox="0 0 24 24" shape-rendering="crispEdges"><path d="${symbol.d}" ${paint}/></svg>`;
  }
  return pixelGlyphSVG(PIXEL_PATTERNS[name], color, size);
}

/** NotchPixelTextView: the app's pixel font for counts. */
export function pixelTextHTML(text, color, size) {
  const spacing = Math.max(1, size * 0.08);
  const glyphs = [...String(text).toUpperCase()]
    .filter((c) => PIXEL_FONT[c])
    .map((c) => `<span style="display:inline-block;width:${size * 0.72}px;height:${size}px">${pixelGlyphSVGRect(PIXEL_FONT[c], color, size * 0.72, size)}</span>`);
  return `<span style="display:inline-flex;gap:${spacing}px">${glyphs.join("")}</span>`;
}

function pixelGlyphSVGRect(pattern, color, width, height) {
  const rows = pattern.length;
  const cols = pattern[0].length;
  const cell = Math.floor(Math.min(width / cols, height / rows));
  const ox = (width - cols * cell) / 2;
  const oy = (height - rows * cell) / 2;
  const px = Math.max(1, cell - 0.8);
  const r = Math.min(1.2, px * 0.22);
  let rects = "";
  pattern.forEach((row, y) => [...row].forEach((c, x) => {
    if (c === "1") rects += `<rect x="${ox + x * cell}" y="${oy + y * cell}" width="${px}" height="${px}" rx="${r}"/>`;
  }));
  return `<svg xmlns="${SVG_NS}" width="${width}" height="${height}" fill="${color}" style="display:block">${rects}</svg>`;
}

// NotchPixelTone
export const TONES = {
  neutral: { plate: "rgba(255,255,255,0.08)", glyph: "rgba(255,255,255,0.86)", glyphRGB: [255, 255, 255, 0.86] },
  accent: { plate: rgb(0.10, 0.23, 0.40), glyph: rgb(0.78, 0.91, 1.0) },
  warning: { plate: rgb(0.29, 0.20, 0.05), glyph: rgb(1.0, 0.88, 0.46) },
  danger: { plate: rgb(0.29, 0.08, 0.09), glyph: rgb(1.0, 0.76, 0.78) },
  success: { plate: rgb(0.07, 0.24, 0.14), glyph: rgb(0.82, 1.0, 0.74) },
  info: { plate: rgb(0.13, 0.18, 0.28), glyph: rgb(0.67, 0.86, 1.0) },
};

export function rgb(r, g, b, a = 1) {
  return `rgba(${Math.round(r * 255)},${Math.round(g * 255)},${Math.round(b * 255)},${a})`;
}

/** Same color at another opacity, for SwiftUI's `color.opacity(x)` on an opaque color. */
export function withAlpha(color, alpha) {
  const m = color.match(/rgba\((\d+),(\d+),(\d+),([\d.]+)\)/);
  if (!m) return color;
  return `rgba(${m[1]},${m[2]},${m[3]},${Number(m[4]) * alpha})`;
}

// ---------------------------------------------------------------------------
// Shapes

/**
 * The notch silhouette (NotchBackgroundView): a rectangle with rounded bottom corners
 * and two concave "shoulders" that blend it into the top edge of the screen.
 */
export function notchPath(cx, w, h, r) {
  const left = cx - w / 2;
  const right = cx + w / 2;
  const br = Math.min(r, h / 2, w / 2);
  return [
    `M ${left - r} 0`,
    `L ${right + r} 0`,
    `A ${r} ${r} 0 0 0 ${right} ${r}`,
    `L ${right} ${h - br}`,
    `A ${br} ${br} 0 0 1 ${right - br} ${h}`,
    `L ${left + br} ${h}`,
    `A ${br} ${br} 0 0 1 ${left} ${h - br}`,
    `L ${left} ${r}`,
    `A ${r} ${r} 0 0 0 ${left - r} 0`,
    "Z",
  ].join(" ");
}

export function el(tag, className, html) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (html !== undefined) node.innerHTML = html;
  return node;
}

export function escapeHTML(text) {
  return String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}
