import SwiftUI

struct MessageInputView: View {
    let isStreaming: Bool
    let isConnected: Bool
    let onSend: (String) -> Void
    let onStop: () -> Void

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $inputText)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 36, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.isEmpty {
                        sendMessage()
                        return .handled
                    }
                    return .ignored
                }

            if isStreaming {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .help("Stop generating")
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isConnected)
                .keyboardShortcut(.return, modifiers: .command)
                .help(isConnected ? "Send message" : "Not connected")
            }
        }
        .padding(12)
        .onAppear { isFocused = true }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        onSend(text)
    }
}
