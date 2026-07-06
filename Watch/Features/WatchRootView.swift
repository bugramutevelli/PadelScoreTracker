import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        Group {
            if let match = store.activeMatch {
                WatchMatchView(match: match)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "figure.padel").font(.largeTitle).foregroundStyle(.green)
                    Text("Ralli hazır").font(.headline)
                    Text("Maçı iPhone’dan başlat.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct WatchMatchView: View {
    @EnvironmentObject private var store: MatchStore
    let match: PadelMatch

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Label(match.currentServerName, systemImage: "figure.padel")
                    Spacer()
                    Text("\(match.currentSet.homeGames)–\(match.currentSet.awayGames)")
                }.font(.caption2).lineLimit(1)

                HStack(spacing: 6) {
                    pointButton(.home, color: .cyan)
                    pointButton(.away, color: .orange)
                }

                HStack {
                    Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(match.history.isEmpty)
                    Text(match.isTieBreak ? "TIE-BREAK" : match.receivingSide)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if let winner = match.winner {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text("Kazanan").font(.caption)
                    Text(match.teamName(winner)).font(.caption.bold()).multilineTextAlignment(.center)
                }
                .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func pointButton(_ team: Team, color: Color) -> some View {
        Button { store.awardPoint(to: team) } label: {
            VStack(spacing: 2) {
                Text(team == .home ? "A" : "B").font(.caption2.bold())
                Text(match.pointLabel(for: team))
                    .font(.system(size: 33, weight: .black, design: .rounded))
            }.frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(color)
    }
}

