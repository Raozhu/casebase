# casebase

[简体中文](README.zh-CN.md)

casebase is a Mac app that lives in the notch. It keeps the files, screenshots, text and meetings you come across at work in one place, and answers questions from them with sources.

Work material rarely arrives in one place. A colleague sends a PDF in chat, a chart you need is on a dashboard, a decision gets made halfway through a meeting. Most of it lands in Downloads, on the desktop or in a chat thread. A week later, when you're writing the review or following up, you can't remember where it went or what exactly was said.

With casebase you save each piece in a second, without deciding where it should go. It reads what you saved, files it, and lets you find it again by asking.

## What you can use it for

**Meetings.** Start a recording from the notch and keep working. When the meeting ends you get the transcript and a list of action items, with owners and due dates where they were mentioned. Add the ones that are yours to your to-do list with one click.

**User research.** Save interview recordings, notes and screenshots as you go. Before writing the summary, ask "what did people say about pricing?" and get an answer that links back to each interview.

**Reports and reviews.** Collect the PDFs colleagues send you, a chart from a dashboard and a paragraph from an article while you work. They end up sorted into folders you never had to create, ready when you sit down to write.

**Finding a decision again.** Ask "what did we decide about launch pricing?" and casebase answers from the meeting where it happened, quoting the part that matters.

**Context for your AI tools.** Connect Claude Code, Codex or any MCP client to casebase, so they can look up your notes and meeting decisions and add to-dos for you.

## How it works

**Save in one move.** Drag files, folders, images, PDFs or audio onto the notch. Press `⌘F1` to save the text you have selected, or `⌘F2` to capture part of the screen.

**casebase reads what you save.** It parses PDFs, Word, Excel and PowerPoint files, images (with OCR), audio and whole folders. A language model writes a title, a summary, key points and tags for each item and files it by purpose. If it can't tell what something is for, it asks you a short question instead of guessing. Saving the same file twice is detected.

**Ask across everything.** Answers are built from your saved items and list the sources they used. Open a source to see the original. Search is full-text by default; add a Google API key to enable semantic search.

**Meetings become to-dos.** Recordings are transcribed on your Mac by a local oMLX server. casebase then pulls out action items with owner, due date and the sentence they came from, and waits for you to accept them.

**Your data stays on your Mac.** The library is a SQLite database plus your original files in `~/Library/Application Support/casebase`. Every item also appears in Finder under `~/Documents/Casebase 标签入口`, sorted by category and tagged. Content is only sent to the model provider you configure.

**Works with your AI tools.** The bundled `casebase-mcp` server lets MCP clients search your records and read, create and update to-dos.

## Get started

1. Download `Casebase-<version>-arm64.dmg` from [Releases](https://github.com/Raozhu/casebase/releases) and drag `casebase.app` into Applications. The app isn't notarized yet: on first launch, open **System Settings → Privacy & Security** and click **Open Anyway**.
2. Hover the notch, open **Settings** and paste a DeepSeek API key.
3. Drag a file onto the notch, or select some text and press `⌘F1`. macOS asks for each permission the first time a feature needs it.

Requires macOS 14 or later on Apple Silicon.

Optional: run an oMLX server for meeting transcription, add a Google API key for semantic search, and download `casebase-mcp` from Releases to connect your AI tools.

## Reference

### Hotkeys and menu

| To | Do this |
|---|---|
| Save files, images, PDFs, audio, folders | Drag them onto the notch |
| Save selected text | `⌘F1` |
| Capture part of the screen | `⌘F2` |
| Record a meeting | Hover the notch → **Record** |
| Browse saved items | Hover the notch → **View data** |
| Ask a question | Hover the notch → **Explore** |
| See to-dos | Hover the notch → **To-do** |
| Open the round table (optional) | `⌘F4` |

Hotkeys can be changed in settings. A recording keeps running while you use other features.

### Configuration

Settings live in `~/Library/Application Support/casebase/.env`. Keys entered in the app are written there.

| Variable | Purpose |
|---|---|
| `DEEPSEEK_API_KEY` | Required. Analysis, answers, image and PDF understanding |
| `CASEBASE_ANALYSIS_MODEL`, `CASEBASE_ANSWER_MODEL` | Model names, default `deepseek-flash` |
| `CASEBASE_GOOGLE_API_KEY` | Optional. Gemini embeddings for semantic search |
| `CASEBASE_STORAGE_ROOT` | Optional. Where the library lives |

Meeting transcription uses a local oMLX server (OpenAI-compatible, model `VibeVoice-ASR-4bit`) configured in `~/.omlx/settings.json`. Without it, recordings are saved but not transcribed.

The round table (`⌘F4`) is an optional local multi-agent group chat started from `KNIGHTS_HOME` on port 3721. Its notes are imported into casebase automatically. Set `KNIGHTS_AUTOSTART=0` to turn it off.

### MCP server

`casebase-mcp` is a stdio MCP server over the same local library.

| Tool | What it does |
|---|---|
| `casebase_list_records`, `casebase_search_records`, `casebase_get_record` | Browse and search saved items |
| `casebase_list_todos`, `casebase_get_todo` | Read to-dos |
| `casebase_create_todo`, `casebase_update_todo` | Create and update to-dos |

```json
{
  "mcpServers": {
    "casebase": { "command": "/path/to/casebase-mcp" }
  }
}
```

### Permissions

- Accessibility: read the selected text (`⌘F1`)
- Screen Recording: capture the screen (`⌘F2`)
- Microphone: record meetings

### Build from source

Open `casebase.xcodeproj` in Xcode 16 or later and run the `casebase` scheme. The `casebase-mcp` scheme builds the MCP server.

## License

[GPL-3.0](LICENSE)
