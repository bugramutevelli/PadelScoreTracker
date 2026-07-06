import SwiftUI

@main
struct PadelScoreTrackerWatchApp: App {
    @StateObject private var store = MatchStore()
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workout)
        }
    }
}
