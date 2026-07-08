import SwiftUI
import UIKit

struct LiveMatchView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var confirmFinish = false

    var body: some View {
        NavigationStack {
            if let match = store.activeMatch {
                VStack(spacing: 18) {
                    topRow(match)
                    scoreHeader(match)

                    HStack(spacing: 12) {
                        pointButton(.home, match: match, color: .cyan)
                        pointButton(.away, match: match, color: .orange)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 10) {
                        undoButton(match)
                        finishButton
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 22)
                .background(Color(red: 0.03, green: 0.05, blue: 0.09).ignoresSafeArea())
                .foregroundStyle(.white)
                .toolbar(.hidden, for: .navigationBar)
                .confirmationDialog("Maç bitirilsin mi?", isPresented: $confirmFinish) {
                    Button("Maçı Bitir", role: .destructive) { store.finishEarly() }
                }
                .overlay { if match.isFinished { winnerOverlay(match) } }
                .preferredColorScheme(.dark)
            }
        }
    }

    private func topRow(_ match: PadelMatch) -> some View {
        HStack {
            Label("\(Int(match.workoutMetrics?.duration ?? match.duration) / 60) dk", systemImage: "timer")
            Spacer()
            Label("Watch eşzamanlı", systemImage: "applewatch")
                .foregroundStyle(.green)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func scoreHeader(_ match: PadelMatch) -> some View {
        VStack(spacing: 10) {
            Text("SET SKORU")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.24))

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("TAKIM A")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.cyan)
                Text("\(match.homeSets)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
                Text(":")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 2)
                Text("\(match.awaySets)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                Text("TAKIM B")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.orange)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)

            Text(matchLine(match))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private func matchLine(_ match: PadelMatch) -> String {
        if match.isTieBreak { return "TIE-BREAK" }
        return "\(match.completedSets.count + 1). SET · OYUN \(match.currentSet.homeGames)–\(match.currentSet.awayGames)"
    }

    private func pointButton(_ team: Team, match: PadelMatch, color: Color) -> some View {
        Button { awardPoint(to: team, in: match) } label: {
            VStack(spacing: 0) {
                Text(team == .home ? "TAKIM A" : "TAKIM B")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .padding(.top, 16)

                Text(match.pointLabel(for: team))
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.52)
                    .lineLimit(1)
                    .padding(.top, 18)

                VStack(spacing: 7) {
                    playerRow(name: team == .home ? match.home.first : match.away.first,
                              index: team == .home ? 0 : 1)
                    playerRow(name: team == .home ? match.home.second : match.away.second,
                              index: team == .home ? 2 : 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 352)
        }
        .buttonStyle(IPhoneScoreButtonStyle(color: color))
    }

    private func awardPoint(to team: Team, in match: PadelMatch) {
        let gamesBefore = totalGames(in: match)
        store.awardPoint(to: team)
        let gamesAfter = store.activeMatch.map(totalGames(in:)) ?? gamesBefore
        playScoreHaptic(gameCompleted: gamesAfter > gamesBefore)
    }

    private func totalGames(in match: PadelMatch) -> Int {
        let completedGames = match.completedSets.reduce(0) { total, set in
            total + set.homeGames + set.awayGames
        }
        return completedGames + match.currentSet.homeGames + match.currentSet.awayGames
    }

    private func playScoreHaptic(gameCompleted: Bool) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        guard gameCompleted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private func playerRow(name: String, index: Int) -> some View {
        let isServing = store.activeMatch?.serverIndex == index

        return HStack(spacing: 5) {
            if isServing {
                Image("TennisBallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            }
            Text(name)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 13, weight: isServing ? .bold : .semibold, design: .rounded))
        .foregroundStyle(isServing
                         ? Color(red: 0.88, green: 1, blue: 0.58)
                         : Color.white.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: 130)
        .background {
            if isServing {
                Capsule().fill(Color(red: 0.70, green: 1, blue: 0.25).opacity(0.14))
            }
        }
        .overlay {
            if isServing {
                Capsule().stroke(Color(red: 0.74, green: 1, blue: 0.32).opacity(0.30), lineWidth: 0.8)
            }
        }
    }

    private func undoButton(_ match: PadelMatch) -> some View {
        Button { store.undo() } label: {
            Label("Undo", systemImage: "arrow.counterclockwise")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.33, blue: 0.96).opacity(0.64),
                            Color(red: 0.43, green: 0.20, blue: 0.88).opacity(0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.8))
                .shadow(color: Color.purple.opacity(0.24), radius: 7, y: 3)
        }
        .buttonStyle(IPhoneUndoButtonStyle())
        .disabled(match.history.isEmpty)
        .opacity(match.history.isEmpty ? 0.45 : 1)
    }

    private var finishButton: some View {
        Button { confirmFinish = true } label: {
            Text("Maçı Bitir")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.red.opacity(0.88), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.8))
        }
        .buttonStyle(IPhoneUndoButtonStyle())
    }

    private func winnerOverlay(_ match: PadelMatch) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.yellow)
                Text("Maç tamamlandı")
                    .font(.title.bold())
                Text(match.teamName(match.winner!))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Sonucu Kaydet") { store.closeCompletedMatch() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(30)
        }
    }
}

private struct IPhoneScoreButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .background(
                color.opacity(configuration.isPressed ? 0.34 : 0.18),
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.62), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 1.025 : 1)
            .shadow(color: color.opacity(configuration.isPressed ? 0.22 : 0.04), radius: 9, y: 4)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private struct IPhoneUndoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

#Preview("iPhone - Canli Mac") {
    LiveMatchView()
        .environmentObject(MatchStore.preview(active: true, scored: true))
}
