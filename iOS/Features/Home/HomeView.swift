import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var home = TeamPlayers.homeDefault
    @State private var away = TeamPlayers.awayDefault
    @State private var rule: ScoringRule = .advantage
    @State private var format: MatchFormat = .bestOfThree
    @State private var firstServerIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Padel Score Tracker")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.24))
                    Spacer()
                    Text("OYNA")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                hero
                teamCard(title: "TAKIM A", players: $home, color: .cyan)
                teamCard(title: "TAKIM B", players: $away, color: .orange)

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("MAÇ AYARLARI")
                    settingRow(title: "Maç formatı", value: format.title) {
                        Picker("Maç formatı", selection: $format) {
                            ForEach(MatchFormat.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    Text(format.explanation).font(.caption).foregroundStyle(.secondary)

                    settingRow(title: "Puanlama", value: rule.title) {
                        Picker("Puanlama", selection: $rule) {
                            ForEach(ScoringRule.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    Text(rule.explanation).font(.caption).foregroundStyle(.secondary)

                    settingRow(title: "İlk servis", value: serverNames[firstServerIndex]) {
                        Picker("İlk servis", selection: $firstServerIndex) {
                            ForEach(serverNames.indices, id: \.self) { index in
                                Text(serverNames[index]).tag(index)
                            }
                        }
                    }
                }

                Button {
                    store.start(home: home, away: away, rule: rule, format: format, firstServerIndex: firstServerIndex)
                } label: {
                    Label("Maçı Başlat", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.07, green: 0.12, blue: 0.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color(red: 0.78, green: 0.96, blue: 0.24), in: RoundedRectangle(cornerRadius: 17))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.03, green: 0.05, blue: 0.09).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var serverNames: [String] { [home.first, away.first, home.second, away.second] }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    private func settingRow<Content: View>(title: String, value: String, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold()).foregroundStyle(.white)
            }
            Spacer()
            control().labelsHidden().pickerStyle(.menu)
        }
        .padding(12)
        .background(Color(red: 0.07, green: 0.10, blue: 0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            Image("PadelHero")
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [
                    .black.opacity(0.48),
                    Color(red: 0.03, green: 0.08, blue: 0.14).opacity(0.14),
                    .clear
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            LinearGradient(
                colors: [.clear, .cyan.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right").font(.title)
                Text("Skor sende,\naklın oyunda.")
                    .font(.system(size: 31, weight: .black, design: .rounded))
            }
            .padding(.top, 30)
            .padding(.leading, 22)
            .padding(.trailing, 22)

            Text("iPhone ve Apple Watch birlikte çalışır.")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 212, alignment: .leading)
                .lineLimit(2)
                .padding(.leading, 22)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .foregroundStyle(.white)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func teamCard(title: String, players: Binding<TeamPlayers>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            Text(players.wrappedValue.displayName)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            TextField("Birinci oyuncu", text: players.first)
                .foregroundStyle(.white)
            Divider().overlay(.white.opacity(0.10))
            TextField("İkinci oyuncu", text: players.second)
                .foregroundStyle(.white)
        }
        .textFieldStyle(.plain)
        .padding()
        .background(Color(red: 0.07, green: 0.10, blue: 0.16), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08)))
    }
}

#Preview("iPhone - Kurulum") {
    NavigationStack {
        HomeView()
            .environmentObject(MatchStore.preview())
    }
    .tint(Color(red: 0.75, green: 0.96, blue: 0.25))
    .previewDevice("iPhone 15 Pro")
}
