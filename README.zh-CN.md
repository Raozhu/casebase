# casebase

[English](README.md)

macOS 上的本地资料收集工具，常驻在屏幕顶部的刘海区域。

它可以把你临时遇到的截图、选中文字、文件、PDF、图片、音频和会议录音保存到一个地方，之后再回看、搜索、继续提问，也能把会议里的待办整理出来。

## 它做什么

- **随手收集**：把文件拖到刘海入口，或用快捷键保存选中文字、截图
- **看懂存下的内容**：文本、PDF、Office 文档、图片（含 OCR）、音频和整个文件夹都会被解析，并由大模型整理成可回看的资料记录
- **基于资料提问**：回答依据你保存过的资料，并标出引用来源
- **会议录音**：录音和转写文本保存成同一条记录，并提取待办建议
- **待办管理**：支持截止日期、筛选，可由 AI 拆分成子任务
- **接入 AI 工具**：附带的 `casebase-mcp` 让 Claude、Codex 等 MCP 客户端可以搜索资料、读写待办

所有数据都保存在你的 Mac 上（SQLite 数据库），只会发送给你自己配置的模型服务。

## 它解决什么问题

工作里很多资料出现得很临时：聊天里的文件、网页上的一段话、临时截的图、会议里的结论。

这些内容通常会散在桌面、下载目录、剪贴板、聊天记录和录音文件夹里。等到后面要找时，很难想起放在哪里，也很难把它们继续用起来。

casebase 解决的是这件事：先快速保存，之后还能找回、看懂、继续使用。

## 安装

1. 从 [Releases](https://github.com/Raozhu/casebase/releases) 下载 `Casebase-<版本号>-arm64.dmg`，把 `casebase.app` 拖进「应用程序」。
2. 应用暂未经过 Apple 公证，第一次打开会被系统拦截：到「系统设置 → 隐私与安全性」里点「仍要打开」。
3. 在刘海里打开设置，填入 DeepSeek API Key。

需要 macOS 14 及以上、Apple 芯片的 Mac。

## 怎么用

| 操作 | 方式 |
|---|---|
| 保存文件、图片、PDF、音频、文件夹 | 拖到刘海入口 |
| 保存当前选中文字 | `⌘F1` |
| 截图并保存 | `⌘F2` |
| 打开圆桌（可选，见下文） | `⌘F4` |
| 会议录音 | 在刘海里打开「录音」，填写人数（默认 2）和主题（可不填） |
| 查看资料、提问 | 在刘海里进入「已存数据」 |

快捷键可以在设置里修改。录音过程中切换到其他功能不会中断。

## 配置

配置从 `~/Library/Application Support/casebase/.env` 读取，应用里填的 API Key 也会写到这里。

| 变量 | 用途 |
|---|---|
| `DEEPSEEK_API_KEY` | 必填。资料分析、问答、图片和 PDF 理解 |
| `CASEBASE_ANALYSIS_MODEL`、`CASEBASE_ANSWER_MODEL` | 模型名，默认 `deepseek-flash` |
| `CASEBASE_GOOGLE_API_KEY` | 选填。启用 Gemini 向量检索（也可以在应用里设置） |
| `CASEBASE_STORAGE_ROOT` | 选填。数据库和资料文件的存放位置，默认 `~/Library/Application Support/casebase` |

**会议转写**使用本地的 oMLX 服务（兼容 OpenAI 接口，模型 `VibeVoice-ASR-4bit`），配置在 `~/.omlx/settings.json`。没有它也能录音，只是不会生成转写文本。

**圆桌**（`⌘F4`）是可选的配套功能：一个本地多智能体群聊服务，从 `KNIGHTS_HOME` 启动，端口 3721，它产生的记忆会自动导入 casebase。设置 `KNIGHTS_AUTOSTART=0` 可以关闭。

## MCP 服务

`casebase-mcp` 是一个 stdio 方式的 MCP 服务，读取同一个本地资料库。提供的工具：

`casebase_list_records`、`casebase_search_records`、`casebase_get_record`、`casebase_list_todos`、`casebase_get_todo`、`casebase_create_todo`、`casebase_update_todo`

客户端配置示例：

```json
{
  "mcpServers": {
    "casebase": { "command": "/path/to/casebase-mcp" }
  }
}
```

## 权限说明

casebase 只在使用对应功能时请求权限：

- 辅助功能：读取当前选中文字
- 屏幕录制：截图
- 麦克风：会议录音

## 从源码构建

用 Xcode 16 及以上打开 `casebase.xcodeproj`，运行 `casebase` scheme；`casebase-mcp` scheme 用来构建 MCP 服务。

## 许可证

[GPL-3.0](LICENSE)
