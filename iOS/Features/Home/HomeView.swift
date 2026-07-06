import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var home = TeamPlayers.homeDefault
    @State private var away = TeamPlayers.awayDefault
    @State private var rule: ScoringRule = .advantage
    @State private var format: MatchFormat = .bestOfThree

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                teamCard(title: "TAKIM A", players: $home, color: .cyan)
                teamCard(title: "TAKIM B", players: $away, color: .orange)

                VStack(alignment: .leading, spacing: 12) {
                    Text("MAÇ AYARLARI").font(.caption.bold()).foregroundStyle(.secondary)
                    Picker("Format", selection: $format) {
                        ForEach(MatchFormat.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    Picker("Skor", selection: $rule) {
                        ForEach(ScoringRule.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }

                Button {
                    store.start(home: home, away: away, rule: rule, format: format)
                } label: {
                    Label("Maçı Başlat", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
            }
            .padding()
        }
        .navigationTitle("Ralli")
        .background(Color(.systemGroupedBackground))
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.indigo, .blue, .cyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 180).offset(x: 220, y: -45)
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right").font(.title)
                Text("Skor sende,\naklın oyunda.").font(.largeTitle.bold())
                Text("iPhone ve Apple Watch birlikte çalışır.").foregroundStyle(.white.opacity(0.8))
            }.padding(22)
        }
        .foregroundStyle(.white)
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func teamCard(title: String, players: Binding<TeamPlayers>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            TextField("Birinci oyuncu", text: players.first)
            Divider()
            TextField("İkinci oyuncu", text: players.second)
        }
        .textFieldStyle(.plain)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

