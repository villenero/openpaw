import SwiftUI

@Observable
@MainActor
final class AppState {
    var selectedConversationID: UUID?
}
