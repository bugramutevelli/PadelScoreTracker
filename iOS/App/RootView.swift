import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Oyna", systemImage: "figure.padel") }
            NavigationStack { HistoryView() }
                .tabItem { Label("Geçmiş", systemImage: "clock.arrow.circlepath") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.activeMatch != nil },
            set: { _ in }
        )) {
            LiveMatchView()
                .environmentObject(store)
        }
    }
}

