# OpenPaw

A native macOS chat client for [OpenClaw](https://github.com/openclaw/openclaw) Gateway, built with SwiftUI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)

## Features

- **WebSocket connection** to OpenClaw Gateway with Ed25519 device authentication
- **Streaming responses** with real-time text updates
- **Markdown rendering** with full block support:
  - Code blocks with syntax highlighting (50+ languages via [HighlightSwift](https://github.com/appstefan/HighlightSwift))
  - Copy-to-clipboard button on code blocks and blockquotes
  - Tables with zebra striping and proportional column widths
  - Headers, lists, blockquotes, inline formatting
- **Auto-connect** on launch and **auto-reconnect** with exponential backoff
- **Conversation persistence** with SwiftData
- **Settings UI** with connection status, debug log, and gateway token configuration

## Requirements

- macOS 14 (Sonoma) or later
- An [OpenClaw](https://github.com/openclaw/openclaw) Gateway instance running locally or remotely

## Build & Run

```bash
# Build and run directly
swift run OpenPaw

# Or build as .app bundle and launch
./build-app.sh
```

## Configuration

On first launch, open **Settings** (Cmd+,) and configure:

1. **WebSocket URL** — default: `ws://127.0.0.1:18789`
2. **Gateway Token** — your OpenClaw gateway authentication token

The app will auto-connect on subsequent launches.

On first connection, OpenClaw may require **device pairing approval** — accept the device from the gateway admin interface or it will be auto-approved for loopback connections.

## Architecture

```
Sources/OpenPaw/
├── App/
│   ├── OpenPawApp.swift          — Entry point, SwiftData setup, auto-connect
│   └── AppState.swift            — Global observable state
├── Services/
│   ├── GatewayService.swift      — WebSocket connection, protocol, reconnection
│   └── DeviceIdentity.swift      — Ed25519 keypair (~/.openpaw/device-identity.key)
├── ViewModels/
│   └── ChatViewModel.swift       — Chat logic, streaming event handling
├── Models/
│   ├── Conversation.swift        — SwiftData model
│   ├── Message.swift             — SwiftData model
│   └── LLMTypes.swift            — Wire protocol types (frames, AnyCodable)
└── Views/
    ├── ContentView.swift         — NavigationSplitView layout
    ├── Chat/
    │   ├── ChatView.swift        — Message list + input
    │   ├── MessageBubbleView.swift
    │   ├── MessageInputView.swift
    │   └── MarkdownView.swift    — Full markdown renderer + syntax highlighting
    ├── Sidebar/
    │   ├── ConversationListView.swift
    │   └── ConversationRowView.swift
    └── Settings/
        └── SettingsView.swift    — Server config, debug log
```

## Protocol

OpenPaw communicates with the OpenClaw Gateway via WebSocket using JSON frames:

- **Handshake**: challenge-response with Ed25519 signed device identity
- **Chat**: `chat.send` with streaming `chat` events (`delta` / `final` states)
- **Protocol version**: 3

See [CLAUDE.md](CLAUDE.md) for the full protocol reference.

## License

MIT
