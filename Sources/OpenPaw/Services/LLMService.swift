import Foundation
import os

private let log = Logger(subsystem: "com.openpaw.app", category: "gateway")

@Observable
@MainActor
final class GatewayService {
    var serverURL: String = "ws://127.0.0.1:18789"
    var gatewayToken: String = ""
    var isConnected: Bool = false
    var connectionError: String?
    var debugLog: String = ""

    private var webSocket: URLSessionWebSocketTask?
    private var requestID: Int = 0
    private var pendingRequests: [String: CheckedContinuation<IncomingFrame, Error>] = [:]
    private var eventHandlers: [String: (IncomingFrame) -> Void] = [:]
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var autoReconnect: Bool = false
    private var reconnectDelay: TimeInterval = 1
    private let deviceIdentity = DeviceIdentity.loadOrCreate()

    private func dbg(_ msg: String) {
        log.info("\(msg)")
        debugLog += msg + "\n"
    }

    // MARK: - Connection

    func connect() async {
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDown()
        autoReconnect = true
        reconnectDelay = 1
        connectionError = nil
        debugLog = ""

        guard let url = URL(string: serverURL) else {
            connectionError = "Invalid URL"
            return
        }

        dbg("Connecting to \(url)...")

        let ws = URLSession.shared.webSocketTask(with: url)
        self.webSocket = ws
        ws.resume()

        // Start receive loop BEFORE waiting for challenge
        startReceiveLoop()

        do {
            dbg("Waiting for connect.challenge...")
            let challenge = try await waitForEvent("connect.challenge", timeout: 10)
            let nonce = challenge.payload?["nonce"]?.stringValue ?? ""
            dbg("Got challenge, nonce: \(nonce.prefix(12))...")

            // Build signed device identity
            let clientID = "openclaw-macos"
            let clientMode = "ui"
            let role = "operator"
            let scopes = ["operator.read", "operator.write"]

            let (signedDevice, _) = try deviceIdentity.buildSignedDevice(
                nonce: nonce,
                token: gatewayToken,
                clientID: clientID,
                clientMode: clientMode,
                role: role,
                scopes: scopes
            )

            let connectParams: [String: AnyCodable] = [
                "minProtocol": AnyCodable(3),
                "maxProtocol": AnyCodable(3),
                "client": AnyCodable([
                    "id": clientID,
                    "version": "0.1.0",
                    "platform": "macos",
                    "mode": clientMode
                ] as [String: Any]),
                "role": AnyCodable(role),
                "scopes": AnyCodable(scopes as [Any]),
                "auth": AnyCodable(["token": gatewayToken] as [String: Any]),
                "device": AnyCodable(signedDevice)
            ]

            dbg("Sending connect request...")
            let response = try await sendRequest(method: "connect", params: connectParams)

            if response.ok == true {
                isConnected = true
                connectionError = nil
                reconnectDelay = 1
                dbg("Connected!")
            } else {
                let msg = response.error?.message ?? "Handshake rejected"
                dbg("Rejected: \(msg)")
                connectionError = msg
                tearDown()
                scheduleReconnect()
            }
        } catch {
            dbg("Failed: \(error)")
            connectionError = error.localizedDescription
            tearDown()
            scheduleReconnect()
        }
    }

    /// User-initiated disconnect — stops auto-reconnect.
    func disconnect() {
        autoReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDown()
    }

    private func tearDown() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false

        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: GatewayError.disconnected)
        }
        pendingRequests.removeAll()
        eventHandlers.removeAll()
    }

    private func scheduleReconnect() {
        guard autoReconnect else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        dbg("Reconnecting in \(Int(delay))s...")

        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.autoReconnect, !Task.isCancelled else { return }
            await self.connect()
        }
    }

    // MARK: - Chat

    func sendChatMessage(_ message: String, sessionKey: String = "agent:main:main") async throws -> IncomingFrame {
        try await sendRequest(method: "chat.send", params: [
            "message": AnyCodable(message),
            "sessionKey": AnyCodable(sessionKey),
            "idempotencyKey": AnyCodable(UUID().uuidString)
        ])
    }

    func getChatHistory(sessionKey: String = "agent:main:main") async throws -> IncomingFrame {
        try await sendRequest(method: "chat.history", params: [
            "sessionKey": AnyCodable(sessionKey)
        ])
    }

    func onEvent(_ id: String, handler: @escaping (IncomingFrame) -> Void) {
        eventHandlers[id] = handler
    }

    func removeEventHandler(_ id: String) {
        eventHandlers.removeValue(forKey: id)
    }

    func clearEventHandlers() {
        eventHandlers.removeAll()
    }

    // MARK: - Internal

    private func nextID() -> String {
        requestID += 1
        return String(requestID)
    }

    private func sendRequest(method: String, params: [String: AnyCodable]) async throws -> IncomingFrame {
        guard let ws = webSocket else { throw GatewayError.disconnected }

        let id = nextID()
        let frame = RequestFrame(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(frame)
        let text = String(data: data, encoding: .utf8)!

        dbg(">> \(method) [id=\(id)]")

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingRequests[id] = continuation

            ws.send(.string(text)) { [weak self] error in
                if let error {
                    Task { @MainActor in
                        self?.dbg("Send error: \(error)")
                        if self?.pendingRequests.removeValue(forKey: id) != nil {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    private func waitForEvent(_ eventName: String, timeout: TimeInterval) async throws -> IncomingFrame {
        try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let handlerID = "wait-\(eventName)-\(UUID().uuidString)"

            self.eventHandlers[handlerID] = { [weak self] frame in
                guard !resumed, frame.type == .event, frame.event == eventName else { return }
                resumed = true
                self?.eventHandlers.removeValue(forKey: handlerID)
                continuation.resume(returning: frame)
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard !resumed else { return }
                resumed = true
                self?.eventHandlers.removeValue(forKey: handlerID)
                self?.dbg("Timeout waiting for \(eventName)")
                continuation.resume(throwing: GatewayError.timeout)
            }
        }
    }

    private func startReceiveLoop() {
        guard let ws = webSocket else { return }

        receiveTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await ws.receive()
                    let text: String
                    switch message {
                    case .string(let s): text = s
                    case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
                    @unknown default: continue
                    }

                    await MainActor.run {
                        self?.dbg("<< \(String(text.prefix(300)))")
                    }

                    guard let data = text.data(using: .utf8),
                          let frame = try? JSONDecoder().decode(IncomingFrame.self, from: data) else {
                        await MainActor.run {
                            self?.dbg("Failed to decode frame")
                        }
                        continue
                    }

                    await self?.dispatchFrame(frame)
                } catch {
                    let errMsg = "\(error)"
                    await MainActor.run {
                        self?.dbg("Receive error: \(errMsg)")
                        if self?.connectionError == nil {
                            self?.connectionError = "Connection lost"
                        }
                        self?.isConnected = false
                        self?.scheduleReconnect()
                    }
                    break
                }
            }
        }
    }

    private func dispatchFrame(_ frame: IncomingFrame) {
        switch frame.type {
        case .res:
            if let id = frame.id, let continuation = pendingRequests.removeValue(forKey: id) {
                continuation.resume(returning: frame)
            }
        case .event:
            dbg("[dispatch] event=\(frame.event ?? "nil"), handlers=\(eventHandlers.count)")
            for (key, handler) in eventHandlers {
                dbg("[dispatch] calling handler: \(key)")
                handler(frame)
            }
        case .req:
            break
        }
    }

}
