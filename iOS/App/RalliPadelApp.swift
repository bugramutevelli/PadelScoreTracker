import SwiftUI

@main
struct RalliPadelApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.lime)
        }
    }
}

private extension ShapeStyle where Self == Color {
    static var lime: Color { Color(red: 0.75, green: 0.96, blue: 0.25) }
}

