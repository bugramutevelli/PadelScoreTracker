import SwiftUI

struct LiveMatchView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var confirmFinish = false

    var body: some View {
        NavigationStack {
            if let match = store.activeMatch {
                VStack(spacing: 16) {
                    header(match)
                    sets(match)
                    scorePanel(match)
                    infoStrip(match)
                    Spacer(minLength: 0)
                    controls(match)
                }
                .padding()
                .background(Color(red: 0.035, green: 0.055, blue: 0.09).ignoresSafeArea())
                .foregroundStyle(.white)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Bitir") { confirmFinish = true }.foregroundStyle(.red)
                    }
                    ToolbarItem(placement: .principal) { Text("CANLI MAÇ").font(.caption.bold()) }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                            .disabled(match.history.isEmpty)
                    }
                }
                .confirmationDialog("Maç bitirilsin mi?", isPresented: $confirmFinish) {
                    Button("Maçı Bitir", role: .destructive) { store.finishEarly() }
                }
                .overlay { if match.isFinished { winnerOverlay(match) } }
            }
        }
    }

    private func header(_ match: PadelMatch) -> some View {
        HStack {
            Label("\(Int(match.duration) / 60) dk", systemImage: "timer")
            Spacer()
            Label("Watch eşzamanlı", systemImage: "applewatch").foregroundStyle(.green)
        }.font(.caption)
    }

    private func sets(_ match: PadelMatch) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(match.home.displayName).lineLimit(1)
                Text(match.away.displayName).lineLimit(1)
            }.font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(match.completedSets.enumerated()), id: \.offset) { index, set in
                VStack(spacing: 12) {
                    Text("\(set.homeGames)")
                    Text("\(set.awayGames)")
                }.overlay(alignment: .top) { Text("S\(index + 1)").font(.caption2).offset(y: -18) }
            }
            VStack(spacing: 12) {
                Text("\(match.currentSet.homeGames)")
                Text("\(match.currentSet.awayGames)")
            }.foregroundStyle(.cyan).overlay(alignment: .top) { Text("ŞİMDİ").font(.caption2).offset(y: -18) }
        }
        .padding(.vertical, 18)
    }

    private func scorePanel(_ match: PadelMatch) -> some View {
        HStack(spacing: 10) {
            scoreTile(team: .home, match: match, color: .cyan)
            scoreTile(team: .away, match: match, color: .orange)
        }
    }

    private func scoreTile(team: Team, match: PadelMatch, color: Color) -> some View {
        Button { store.awardPoint(to: team) } label: {
            VStack(spacing: 6) {
                Text(team == .home ? "TAKIM A" : "TAKIM B").font(.caption.bold())
                Text(match.pointLabel(for: team)).font(.system(size: 72, weight: .black, design: .rounded))
                Label("Puan ekle", systemImage: "plus.circle.fill").font(.caption.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.55)))
        }.buttonStyle(.plain).foregroundStyle(color)
    }

    private func infoStrip(_ match: PadelMatch) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SERVİS").font(.caption2).foregroundStyle(.secondary)
                Label("\(match.currentServerName) · \(match.currentServerTeam == .home ? "Takım A" : "Takım B")", systemImage: "figure.padel")
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(match.decidingPointLabel ?? (match.isTieBreak ? "TIE-BREAK" : match.receivingSide))
                if match.isDecidingPoint { Text("Karşılayan taraf seçer").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .font(.subheadline.bold()).padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func controls(_ match: PadelMatch) -> some View {
        Text("Puana basmak için takım kartına dokun • Yanlış puanı geri alabilirsin")
            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }

    private func winnerOverlay(_ match: PadelMatch) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "trophy.fill").font(.system(size: 54)).foregroundStyle(.yellow)
                Text("Maç tamamlandı").font(.title.bold())
                Text(match.teamName(match.winner!)).font(.headline).multilineTextAlignment(.center)
                Button("Sonucu Kaydet") { store.closeCompletedMatch() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }.padding(30)
        }
    }
}
