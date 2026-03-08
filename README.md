<div align="center">

# OpenPaw

**A native macOS chat client for [OpenClaw](https://github.com/openclaw/openclaw) Gateway**

Built with SwiftUI &bull; Streaming responses &bull; Rich markdown &bull; Multi-modal media

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)

</div>

---

## Highlights

- **Streaming with typewriter effect** — Adaptive-speed character reveal with alpha fade-in on trailing characters. Text materializes smoothly instead of jumping in chunks.
- **Full markdown rendering** — Code blocks with syntax highlighting (50+ languages), tables, blockquotes, lists, headings, inline formatting. Copy button on hover.
- **Multi-modal messages** — Inline images (base64 & URL), audio player with play/pause and seekable progress bar. Click images to open full-size popup.
- **Emoji picker** — Type `:` followed by 2+ characters to search 500+ emojis in English and Spanish. Arrow keys to navigate, Enter to insert.
- **Auto-connect & reconnect** — Connects on launch, reconnects with exponential backoff (1s → 30s max) on connection loss.
- **Conversation persistence** — All chats saved locally with SwiftData. Auto-titling from first response.

## Requirements

- macOS 14 (Sonoma) or later
- An [OpenClaw](https://github.com/openclaw/openclaw) Gateway instance

## Quick Start

```bash
# Clone and run
git clone https://github.com/villenero/openpaw.git
cd openpaw
swift run OpenPaw

# Or build as .app bundle
./build-app.sh
```

Open **Settings** (Cmd+,) and configure:

| Setting | Default | Description |
|---------|---------|-------------|
| WebSocket URL | `ws://127.0.0.1:18789` | Gateway address |
| Gateway Token | — | Authentication token from OpenClaw |

The app auto-connects on subsequent launches. On first connection, OpenClaw may require device pairing approval — loopback connections are auto-approved.

## Features

### Streaming & Typewriter Effect

Responses stream in real-time with an adaptive buffer system:

- **Large buffer (>100 chars):** 3 chars every 2ms — catches up fast
- **Medium buffer (20-100):** 1 char every 2-8ms — smooth flow
- **Small buffer (<20):** 1 char every 15ms — natural pace

The last 6 characters fade in with decreasing opacity (0.15 → 0.92), creating a subtle materialization effect. On completion, all text snaps to full opacity instantly.

### Markdown Rendering

| Feature | Details |
|---------|---------|
| Code blocks | Syntax highlighting for 50+ languages via [HighlightSwift](https://github.com/appstefan/HighlightSwift), Atom One theme |
| Tables | Zebra striping, proportional column widths, alignment support |
| Lists | Ordered and unordered, with inline image support |
| Blockquotes | Styled with left border, copy button on hover |
| Images | `![alt](url)` rendered inline as thumbnails, click to expand |
| Inline | Bold, italic, strikethrough, links, code spans |

### Multi-Modal Content

**Images** from assistant responses:
- Base64-encoded (`{type: "image", source: {type: "base64", ...}}`)
- URL-referenced (`{type: "image", source: {type: "url", ...}}`)
- Markdown syntax (`![alt](url)`) — standalone or inline in text/lists
- Natural sizing up to 400pt max, 8pt rounded corners
- Click to open full-size popup (Esc or click outside to close)
- Multiple images display as horizontal scrollable grid

**Audio** from assistant responses:
- Inline player: play/pause, seekable progress bar, mm:ss time display
- Single audio at a time — playing a new one pauses the previous
- Supports base64 and URL sources

### Emoji Picker

Type `:` followed by 2+ characters anywhere in the input to trigger autocomplete:

- **500+ emojis** with English and Spanish keywords
- Prefix matches ranked first, then contains matches (max 8 results)
- Arrow keys to navigate, Enter/Tab to select, Esc to dismiss
- Smart detection: skips URLs (`http://`), double colons (`::`)
- Blur background, rounded corners

### Connection & Authentication

- Ed25519 device identity generated and stored at `~/.openpaw/device-identity.key`
- v2 signed payload: `deviceId|clientId|clientMode|role|scopes|signedAt|token|nonce`
- Protocol v3 challenge-response handshake
- Auto-reconnect with exponential backoff (1s, 2s, 4s, ... up to 30s)
- Agent lifecycle tracking (typing indicator during processing)

## Architecture

```
Sources/OpenPaw/
├── App/
│   ├── OpenPawApp.swift              Entry point, SwiftData container, auto-connect
│   └── AppState.swift                Global observable state
├── Services/
│   ├── LLMService.swift              WebSocket connection, protocol v3, reconnection
│   ├── DeviceIdentity.swift          Ed25519 keypair management
│   └── AudioPlayerManager.swift      Singleton audio playback controller
├── ViewModels/
│   └── ChatViewModel.swift           Streaming, typewriter buffer, media extraction
├── Models/
│   ├── Conversation.swift            SwiftData model (title, system prompt, timestamps)
│   ├── Message.swift                 SwiftData model (role, content, media JSON)
│   ├── LLMTypes.swift                Wire protocol types, AnyCodable, error types
│   ├── MediaItem.swift               Image/audio content enum (Codable)
│   └── EmojiDictionary.swift         500+ emoji entries with bilingual keywords
└── Views/
    ├── ContentView.swift             NavigationSplitView layout
    ├── Chat/
    │   ├── ChatView.swift            Message list, scroll management, streaming bubble
    │   ├── MessageBubbleView.swift   User/assistant bubbles with media support
    │   ├── MessageInputView.swift    TextEditor, keyboard shortcuts, emoji picker
    │   ├── MarkdownView.swift        Block parser + renderer (code, tables, images, etc.)
    │   ├── TypewriterTextView.swift  AttributedString with trailing alpha fade
    │   ├── TypingIndicatorView.swift Animated bouncing dots
    │   ├── MediaContentView.swift    Image grid + audio player layout
    │   ├── ImageThumbnailView.swift  Async image loading, natural sizing
    │   ├── ImagePopupView.swift      Full-size modal viewer
    │   ├── AudioPlayerView.swift     Inline audio controls
    │   └── EmojiPickerView.swift     Autocomplete dropdown
    ├── Sidebar/
    │   ├── ConversationListView.swift  Chat list with new/delete
    │   └── ConversationRowView.swift   Preview with last message
    └── Settings/
        └── SettingsView.swift        Server config, status, debug log
```

## Protocol

OpenPaw communicates with the OpenClaw Gateway via WebSocket JSON frames:

```
Client                          Gateway
  │                                │
  │──── WebSocket connect ────────>│
  │<─── connect.challenge (nonce) ─│
  │──── connect.resolve (signed) ─>│
  │<─── connect.resolve (ok) ──────│
  │                                │
  │──── chat.send ────────────────>│
  │<─── event: chat (delta) ───────│  ← accumulated text
  │<─── event: chat (delta) ───────│
  │<─── event: chat (final) ───────│  ← complete response
  │                                │
```

See [CLAUDE.md](CLAUDE.md) for the full protocol reference.

## License

MIT
