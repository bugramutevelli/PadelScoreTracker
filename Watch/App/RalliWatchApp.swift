import SwiftUI

@main
struct RalliWatchApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView().environmentObject(store)
        }
    }
}

