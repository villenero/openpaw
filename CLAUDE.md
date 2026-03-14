# CLAUDE.md — OpenPaw Project Context

## What is OpenPaw?

A native macOS SwiftUI desktop chat client that connects to an **OpenClaw Gateway** via WebSocket. Think of it as a lightweight, native alternative to the OpenClaw TUI or Control UI webchat.

## Tech Stack
- **Language:** Swift 5.10+
- **UI:** SwiftUI, macOS 14+
- **Persistence:** SwiftData (Conversation + Message models)
- **Transport:** URLSessionWebSocketTask → OpenClaw Gateway WebSocket
- **Auth:** Ed25519 device identity + gateway token

## Architecture

```
OpenPawApp (entry point)
├── Services/
│   ├── GatewayService.swift    — WebSocket connection, protocol, send/receive
│   └── DeviceIdentity.swift    — Ed25519 keypair for device auth (Keychain-backed)
├── ViewModels/
│   └── ChatViewModel.swift     — Chat logic, streaming, event handling
├── Models/
│   ├── Conversation.swift      — SwiftData model
│   ├── Message.swift           — SwiftData model  
│   └── LLMTypes.swift          — Wire protocol types (frames, AnyCodable, errors)
├── Views/
│   ├── ContentView.swift       — NavigationSplitView (sidebar + detail)
│   ├── Chat/
│   │   ├── ChatView.swift      — Message list + input
│   │   ├── MessageBubbleView.swift — Individual message bubble
│   │   └── MessageInputView.swift  — Text input + send/stop buttons
│   ├── Sidebar/
│   │   ├── ConversationListView.swift
│   │   └── ConversationRowView.swift
│   └── Settings/
│       └── SettingsView.swift  — Server URL, token, debug log
└── App/
    ├── OpenPawApp.swift        — @main, ModelContainer setup
    └── AppState.swift          — Global observable state
```

## OpenClaw Gateway WebSocket Protocol

### Connection
- URL: `ws://127.0.0.1:18789` (default local gateway)
- Auth: Bearer token + Ed25519 device signing
- Protocol version: 3

### Frame Types
- **Request:**  `{type:"req", id:"<str>", method:"<str>", params:{...}}`
- **Response:** `{type:"res", id:"<str>", ok:true|false, payload:{...}, error:{code,message}}`
- **Event:**    `{type:"event", event:"<str>", payload:{...}}`

### Handshake Flow
1. Server sends `connect.challenge` event with `{nonce:"..."}`
2. Client sends `connect` request with signed device identity + auth token
3. Server responds with `hello-ok`

### Chat Methods
- `chat.send` — Send a message. Params: `{message, sessionKey, idempotencyKey}`
  - Returns ACK immediately: `{runId, status:"started"}`
  - Response streams via events (see below)
- `chat.history` — Get conversation history. Params: `{sessionKey}`
- `chat.abort` — Abort active run. Params: `{sessionKey}`

### Event: "chat" — Agent responses
```json
{
  "type": "event",
  "event": "chat", 
  "payload": {
    "sessionKey": "agent:main:main",
    "runId": "xxx",
    "state": "delta" | "final" | "aborted" | "error",
    "message": { "content": [{"type": "text", "text": "..."}], ... },
    "errorMessage": "..."
  }
}
```

**States:**
- `"delta"` — Streaming update. `message` contains the **full accumulated text so far** (NOT an incremental delta). Replace displayed text, don't append.
- `"final"` — Complete response. `message` contains the final full message.
- `"aborted"` — Run was aborted by user.
- `"error"` — Run failed. Check `errorMessage`.

**Extracting text from `message`:**
- If `message.content` is an array: iterate, filter `type=="text"`, concatenate `.text` fields
- If `message.content` is a string: use directly
- The message may also have `stopReason` (string) on final

### Event: "agent" — Tool calls & lifecycle
```json
{
  "type": "event",
  "event": "agent",
  "payload": {
    "runId": "xxx",
    "seq": 1,
    "stream": "tool" | "lifecycle" | "text" | "thinking",
    "ts": 1234567890,
    "data": { ... }
  }
}
```

**Streams:**
- `"lifecycle"` — Run lifecycle. `data.phase`: `"start"` | `"end"` | `"error"`
  - `"start"` → agent began processing (show typing indicator)
  - `"end"` → agent finished
  - `"error"` → agent error
- `"tool"` — Tool execution. `data.phase`: `"start"` | `"update"` | `"result"`
  - `data.name`: tool name, `data.toolCallId`: unique ID
  - `data.args`: tool arguments (on start)
  - `data.result`: tool result (on result)
- `"text"` — Text streaming (internal)
- `"thinking"` — Model thinking/reasoning (optional)

### Valid connect params
- `client.id`: `"cli"` | `"webchat"` | `"webchat-ui"` | `"openclaw-control-ui"` | `"gateway-client"` | `"openclaw-macos"` | `"openclaw-ios"` | `"openclaw-android"` | `"node-host"` | `"fingerprint"` | `"openclaw-probe"` | `"test"`
- `client.mode`: `"cli"` | `"ui"` | `"webchat"` | `"node"` | `"backend"` | `"probe"` | `"test"`
- `role`: `"operator"` | `"node"`
- `scopes` (operator): `["operator.read", "operator.write"]`

### Default session
- Session key: `"agent:main:main"` (agent:agentId:sessionKey)

### Sending attachments with chat.send
```json
{
  "method": "chat.send",
  "params": {
    "sessionKey": "agent:main:main",
    "message": "optional caption text",
    "idempotencyKey": "uuid",
    "attachments": [
      {
        "type": "image",
        "mimeType": "image/png",
        "content": "<base64-encoded-data-without-data-url-prefix>"
      }
    ]
  }
}
```
- `type`: `"image"` for images
- `mimeType`: the MIME type (e.g. `image/png`, `image/jpeg`, `image/webp`)
- `content`: raw base64 string (NOT a data URL — strip the `data:...;base64,` prefix)
- Multiple attachments supported in the array
- Message text can be empty if only sending attachments

## Build & Run
```bash
cd ~/code/openpaw
swift build
swift run OpenPaw
# or: ./build-app.sh
```

## Guidelines
- Keep the codebase clean and SwiftUI-idiomatic
- Use @Observable (not ObservableObject) — already in use
- SwiftData for persistence (already set up)
- No external dependencies unless absolutely necessary
- Target macOS 14+ only

## Git Discipline — MANDATORY
1. **Commit before starting:** If there are uncommitted changes, commit them first with message `wip: save state before <task>`
2. **Stay in scope:** Only touch the files/functions specified in the task. Do NOT refactor, reorganize, or "improve" unrelated code.
3. **Commit after completing:** Commit your changes with a descriptive message: `feat:`, `fix:`, `refactor:` prefix
4. **Build before committing:** Always run `swift build` and verify it succeeds before committing
5. **One task = one commit:** Don't mix multiple unrelated changes

If something breaks, we need to be able to `git revert` cleanly. No exceptions.
