import SwiftUI

@main
struct PadelScoreTrackerWatchApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView().environmentObject(store)
        }
    }
}
