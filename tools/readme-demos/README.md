# README demos

The animations in the project README are HTML, so the same pages can be embedded on a website. They are recorded to GIF (for GitHub) and MP4.

## Layout

- `web/` — the HTML demos.
  - `demo.html?scene=<scene>&lang=en|zh` plays a scene in a loop. Scenes: `drop`, `text`, `shot`, `ask`, `meeting`, `roundtable`, `mcp`.
  - `engine.js` — deterministic timeline, SwiftUI-style springs, pixel icons.
  - `icons.js` — generated from `casebase/Notch/Components/NotchPixelArt.swift` by `extract_icons.py`. Run `npm run icons` after changing app icons.
  - `record.mjs` — seeks each frame in WebKit and writes `build/readme-demos/web/<scene>-<lang>.{gif,mp4}`.
  - `record-live.mjs`, `setup-knights.mjs` — the round-table scene embeds a live 12 Knights page, so it is recorded in real time.
  - `record-all.sh` — records every scene in both languages.
- `*.swift`, `build.sh` — a reference renderer that runs the app's real SwiftUI notch views offscreen with demo data. Its frames are the ground truth the HTML is compared against, and `seed` writes the demo library into a real `casebase.sqlite` for the round-table and MCP scenes.

Sizes, colors, fonts and animation curves in the HTML follow the SwiftUI source. After changing the notch UI, render the same state with both and compare:

```bash
tools/readme-demos/build.sh
build/readme-demos/DemoRenderer.app/Contents/MacOS/DemoRenderer probe "$PWD/build/readme-demos/probe-zh" -casebase.language zh-Hans
```

## Recording

```bash
cd tools/readme-demos/web && npm install
build/readme-demos/DemoRenderer.app/Contents/MacOS/DemoRenderer seed "$PWD/build/readme-demos/demo-cb-zh" -casebase.language zh-Hans
build/readme-demos/DemoRenderer.app/Contents/MacOS/DemoRenderer seed "$PWD/build/readme-demos/demo-cb-en" -casebase.language en
tools/readme-demos/web/record-all.sh
```

The round-table scene needs a copy of 12 Knights in `build/readme-demos/knights`, without its `data/`, `projects/` and `secrets.json`. `record-all.sh` runs it in `MOCK=1` mode on port 3799 against the demo library, so no real AI is called and no real data is read or written.

All records, conversations and names in the demos are made up.
