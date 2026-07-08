import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem {
                    Label {
                        Text("Oyna")
                    } icon: {
                        Image("PadelPlayIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
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
        .tint(Color(red: 0.78, green: 0.96, blue: 0.24))
        .toolbarBackground(Color(red: 0.03, green: 0.05, blue: 0.09), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
