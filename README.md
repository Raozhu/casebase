# casebase

[简体中文](README.zh-CN.md)

A local-first capture tool for macOS that lives in the notch.

Save screenshots, selected text, files, PDFs, images, audio and meeting recordings to one place, then find them again, ask questions about them, and turn meetings into to-dos.

## What it does

- **Capture from anywhere**: drop files onto the notch, or use a hotkey to save the selected text or a screenshot
- **Understand what you saved**: text, PDFs, Office documents, images (with OCR), audio and whole folders are parsed and summarized by an LLM
- **Ask your library**: answers are grounded in your saved records and cite their sources
- **Record meetings**: audio and transcript are saved together as one record, and action items are suggested as to-dos
- **Manage to-dos**: due dates, filters, and AI-assisted breakdown into subtasks
- **Use it from your AI tools**: the bundled `casebase-mcp` server lets MCP clients (Claude, Codex, …) search records and read or update to-dos

Everything is stored on your Mac in a SQLite database. Content is only sent to the model provider you configure.

## Why

Useful material shows up at random: a file in a chat, a paragraph on a web page, a quick screenshot, a decision made in a meeting. It ends up scattered across the desktop, Downloads, the clipboard and chat history, and is hard to find when you need it.

casebase is about saving it in one step, and being able to find it, understand it and use it later.

## Install

1. Download `Casebase-<version>-arm64.dmg` from [Releases](https://github.com/Raozhu/casebase/releases) and drag `casebase.app` into Applications.
2. The app is not notarized yet. On first launch macOS will block it: open **System Settings → Privacy & Security** and click **Open Anyway**.
3. Open settings from the notch and enter a DeepSeek API key.

Requires macOS 14 or later on Apple Silicon.

## Usage

| Action | How |
|---|---|
| Save files, images, PDFs, audio, folders | Drag them onto the notch |
| Save selected text | `⌘F1` |
| Take and save a screenshot | `⌘F2` |
| Open the round table (optional, see below) | `⌘F4` |
| Record a meeting | Open **Record** in the notch, set the number of speakers and an optional topic |
| Browse and ask questions | Open **Stored Data** in the notch |

Hotkeys can be changed in settings.

## Configuration

Settings are read from `~/Library/Application Support/casebase/.env`. The API key entered in the app is written there too.

| Variable | Purpose |
|---|---|
| `DEEPSEEK_API_KEY` | Required. Analysis, answers, and image/PDF understanding |
| `CASEBASE_ANALYSIS_MODEL`, `CASEBASE_ANSWER_MODEL` | Model names, default `deepseek-flash` |
| `CASEBASE_GOOGLE_API_KEY` | Optional. Enables Gemini embeddings for semantic search (can also be set in the app) |
| `CASEBASE_STORAGE_ROOT` | Optional. Where the database and assets live, default `~/Library/Application Support/casebase` |

**Meeting transcription** uses a local oMLX server (OpenAI-compatible, model `VibeVoice-ASR-4bit`), configured in `~/.omlx/settings.json`. Without it, recording still works but no transcript is produced.

**Round table** (`⌘F4`) is an optional companion: a local multi-agent group chat started from `KNIGHTS_HOME` on port 3721. Its memories are imported into casebase automatically. Set `KNIGHTS_AUTOSTART=0` to turn it off.

## MCP server

`casebase-mcp` is a stdio MCP server that reads the same local library. Tools:

`casebase_list_records`, `casebase_search_records`, `casebase_get_record`, `casebase_list_todos`, `casebase_get_todo`, `casebase_create_todo`, `casebase_update_todo`

Example client configuration:

```json
{
  "mcpServers": {
    "casebase": { "command": "/path/to/casebase-mcp" }
  }
}
```

## Permissions

casebase asks for each permission only when you use the feature that needs it:

- Accessibility: read the selected text
- Screen Recording: take screenshots
- Microphone: record meetings

## Build from source

Open `casebase.xcodeproj` in Xcode 16 or later and run the `casebase` scheme. The `casebase-mcp` scheme builds the MCP server.

## License

[GPL-3.0](LICENSE)
