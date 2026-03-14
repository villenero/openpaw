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
- **Full markdown rendering** — Code blocks with syntax highlighting (50+ languages), tables, blockquotes, lists, headings, inline formatting. Native text selection across paragraphs.
- **Multi-modal messages** — Inline images (base64 & URL), audio player with play/pause and seekable progress bar. Click images to open full-size popup.
- **Floating input bar** — Rounded input field with attachment menu (+), overlays the chat with scroll-to-bottom arrow when needed.
- **Cross-paragraph text selection** — Native NSTextView rendering for full text selection across all content blocks within a message.
- **Emoji picker** — Type `:` followed by 2+ characters to search 500+ emojis in English and Spanish. Arrow keys to navigate, Enter to insert.
- **Bottom-anchored scroll** — Content stays pinned to the bottom when resizing the window. No text lost during reflow.
- **Color themes** — 8 color themes (Sky, Teal, Matcha, Peach, Lilac, Navy, Dark + Default) applied across bubbles, send button, typing dots, scroll arrow, audio player, and emoji picker. Telegram-style swatch grid in Settings.
- **Auto-connect & reconnect** — Connects on launch, reconnects with exponential backoff (1s to 30s max) on connection loss.
- **Conversation persistence** — All chats saved locally with SwiftData. Auto-titling from first response. Restores last conversation on relaunch.
- **Single-instance app** — Prevents multiple windows from opening.
- **Smart input blocking** — Send button disabled while assistant is streaming to prevent message loss.

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

### Chat Interface

- **Assistant messages** render full-width with no background bubble for maximum readability
- **User messages** appear in colored bubbles aligned to the right (color customizable in Settings)
- **Floating input bar** with rounded border, adaptive dark/light styling, and attachment menu
- **Scroll-to-bottom arrow** appears when you scroll up, click to jump back to latest content
- **Bottom-anchored scroll** — resizing the window keeps content pinned at the bottom, reflow pushes upward
- **Typing indicator** — animated bouncing dots while the assistant is processing

### Streaming & Typewriter Effect

Responses stream in real-time with an adaptive buffer system:

- **Large buffer (>200 chars):** flushes to within 20 chars of target instantly
- **Medium buffer (30-80):** 1-3 chars every 2-8ms — smooth flow
- **Small buffer (<10):** 1 char every 15ms — natural pace

The last 20 characters fade in with increasing opacity, creating a subtle materialization effect. On completion, all text snaps to full opacity instantly.

### Markdown Rendering

All text is rendered via a single NSTextView per message for native cross-paragraph text selection.

| Feature | Details |
|---------|---------|
| Code blocks | Syntax highlighting (50+ languages) via [HighlightSwift](https://github.com/appstefan/HighlightSwift), Atom One theme, dark background with language label |
| Tables | Zebra striping, proportional column widths, alignment support |
| Lists | Ordered and unordered with proper indentation and line spacing |
| Blockquotes | Styled with indent and secondary color |
| Images | `![alt](url)` rendered inline as thumbnails, click to expand |
| Inline | Bold, italic, strikethrough, links, code spans |
| Typography | 14pt body font, 4pt line spacing, 6pt paragraph spacing |

### Attachments

The **+** button in the input bar opens a popover with options:

- **Image** — Pick images via file browser
- **File** — Attach any file
- **Paste from clipboard** — Insert image from clipboard

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

### Settings

Tabbed settings window (Cmd+,):

- **General** — Input behavior, server URL, gateway token, connection status, debug log
- **Appearance** — Color theme picker (8 themes), Light/Dark/Auto mode

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
│   ├── AppState.swift                Global observable state
│   └── BuildInfo.swift               Auto-generated build timestamp
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
│   ├── ColorTheme.swift              8 color themes with gradients, accents, bubble colors
│   └── EmojiDictionary.swift         500+ emoji entries with bilingual keywords
└── Views/
    ├── ContentView.swift             NavigationSplitView layout
    ├── Chat/
    │   ├── ChatView.swift            Message list, flipped scroll, streaming bubble
    │   ├── MessageBubbleView.swift   User bubbles + full-width assistant blocks
    │   ├── MessageInputView.swift    Floating input, attachment menu, emoji picker
    │   ├── MarkdownView.swift        Block parser + NSTextView renderer
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
        └── SettingsView.swift        Tabbed settings (General + Appearance)
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
