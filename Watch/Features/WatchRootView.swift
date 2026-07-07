import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        Group {
            if let match = store.activeMatch {
                WatchMatchView(match: match)
            } else {
                WatchQuickStartView()
            }
        }
        .onChange(of: store.activeMatch?.id) { _, matchID in
            if matchID == nil && workout.isRunning {
                workout.endWorkout()
            }
        }
        .task {
            store.requestActiveMatch()
        }
    }
}

private struct WatchQuickStartView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: "figure.padel")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.green)

                Text("Padel Score")
                    .font(.headline)

                NavigationLink {
                    WatchQuickMatchSetupView()
                } label: {
                    Label("Hızlı Maç Başlat", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.75, green: 0.96, blue: 0.25))
                .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.02))
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct WatchQuickMatchSetupView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var format: MatchFormat = .bestOfThree
    @State private var rule: ScoringRule = .advantage

    var body: some View {
        List {
            Section("Kurallar") {
                Picker("Format", selection: $format) {
                    ForEach(MatchFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                Picker("Puanlama", selection: $rule) {
                    ForEach(ScoringRule.allCases) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
            }

            Button {
                store.start(
                    home: .homeDefault,
                    away: .awayDefault,
                    rule: rule,
                    format: format,
                    firstServerIndex: 0
                )
                dismiss()
            } label: {
                Label("Başlat", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color(red: 0.75, green: 0.96, blue: 0.25))
            .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.02))
        }
        .navigationTitle("Hızlı Maç")
    }
}

private struct WatchMatchView: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var workout: WorkoutManager
    let match: PadelMatch

    var body: some View {
        TabView {
            scoreboardPage
            workoutPage
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .task {
            let authorized = await workout.requestAuthorization()
            if authorized && !workout.isRunning && !match.isFinished {
                workout.startWorkout()
            }
        }
        .onChange(of: Int(workout.metrics.duration / 15)) { _, _ in
            store.updateWorkoutMetrics(workout.metrics)
        }
        .onChange(of: match.isFinished) { _, finished in
            guard finished else { return }
            store.updateWorkoutMetrics(workout.metrics)
            workout.endWorkout()
        }
        .onChange(of: workout.isRunning) { _, running in
            if !running { store.updateWorkoutMetrics(workout.metrics) }
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

    private var scoreboardPage: some View {
        VStack(spacing: 12) {
            scoreHeader

            HStack(spacing: 6) {
                pointButton(.home, color: .cyan)
                pointButton(.away, color: .orange)
            }
            .frame(width: 174)

            Spacer(minLength: 0)

            Button { store.undo() } label: {
                Label("Undo", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 42)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.68, green: 0.33, blue: 0.96).opacity(0.64),
                                     Color(red: 0.43, green: 0.20, blue: 0.88).opacity(0.46)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.7))
                    .shadow(color: Color.purple.opacity(0.22), radius: 5, y: 2)
            }
            .buttonStyle(WatchUndoButtonStyle())
            .disabled(match.history.isEmpty)
            .opacity(match.history.isEmpty ? 0.45 : 1)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 0) {
            Text("SETLER")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.secondary)
            Text("\(match.homeSets)–\(match.awaySets)")
                .font(.system(size: 25, weight: .black, design: .rounded))
            Text(match.isTieBreak
                 ? "TIE-BREAK"
                 : "\(match.completedSets.count + 1). SET  ·  OYUN \(match.currentSet.homeGames)–\(match.currentSet.awayGames)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    private var workoutPage: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PADEL")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.green)
                Spacer()
                Image(systemName: "figure.tennis")
                    .foregroundStyle(.green)
            }

            Text(workoutDuration)
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundStyle(.yellow)
                .monospacedDigit()

            Divider().overlay(.white.opacity(0.16))

            LazyVGrid(columns: [.init(.flexible(), alignment: .leading), .init(.flexible(), alignment: .leading)], spacing: 9) {
                workoutMetric("AKTİF KALORİ", "\(Int(workout.metrics.activeCalories)) KCAL", .pink)
                workoutMetric("NABIZ", "\(Int(workout.metrics.heartRate)) BPM", .red)
                workoutMetric("MESAFE", String(format: "%.2f KM", workout.metrics.distanceMeters / 1000), .cyan)
                workoutMetric("ADIM", "\(workout.metrics.steps)", .green)
            }

            Spacer(minLength: 0)

            Text("Skora dönmek için sağa kaydır")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
    }

    private var workoutDuration: String {
        let total = Int(workout.metrics.duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func workoutMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
    }

    private func pointButton(_ team: Team, color: Color) -> some View {
        Button { store.awardPoint(to: team) } label: {
            VStack(spacing: 0) {
                Text(team == .home ? "TAKIM A" : "TAKIM B")
                    .font(.system(size: 9, weight: .black))
                    .padding(.top, 8)
                Text(match.pointLabel(for: team))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .padding(.top, 7)
                VStack(spacing: -2) {
                    playerRow(name: team == .home ? match.home.first : match.away.first,
                              index: team == .home ? 0 : 1)
                    playerRow(name: team == .home ? match.home.second : match.away.second,
                              index: team == .home ? 2 : 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }.frame(maxWidth: .infinity, minHeight: 146)
        }
        .buttonStyle(WatchScoreButtonStyle(color: color))
    }

    private func playerRow(name: String, index: Int) -> some View {
        let isServing = match.serverIndex == index

        return HStack(spacing: 3) {
            if isServing {
                Image("TennisBallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
            }
            Text(name).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(.system(size: 10, weight: isServing ? .bold : .semibold, design: .rounded))
        .tracking(0.05)
        .foregroundStyle(isServing
                         ? Color(red: 0.88, green: 1, blue: 0.58)
                         : Color.white.opacity(0.86))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background {
            if isServing {
                Capsule().fill(Color(red: 0.70, green: 1, blue: 0.25).opacity(0.14))
            }
        }
        .overlay {
            if isServing {
                Capsule().stroke(Color(red: 0.74, green: 1, blue: 0.32).opacity(0.28), lineWidth: 0.7)
            }
        }
    }
}

private struct WatchScoreButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .background(
                color.opacity(configuration.isPressed ? 0.34 : 0.18),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .scaleEffect(configuration.isPressed ? 1.035 : 1)
            .shadow(
                color: color.opacity(configuration.isPressed ? 0.24 : 0),
                radius: configuration.isPressed ? 5 : 0
            )
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private struct WatchUndoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

#Preview("Watch - Hazir") {
    WatchRootView()
        .environmentObject(MatchStore.preview())
        .environmentObject(WorkoutManager.preview(running: false))
        .previewDevice("Apple Watch Series 9 (45mm)")
}

#Preview("Watch - Mac") {
    WatchRootView()
        .environmentObject(MatchStore.preview(active: true, scored: true))
        .environmentObject(WorkoutManager.preview())
        .previewDevice("Apple Watch Series 9 (45mm)")
}
