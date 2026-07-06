import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        Group {
            if let match = store.activeMatch {
                WatchMatchView(match: match)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "figure.padel").font(.largeTitle).foregroundStyle(.green)
                    Text("Padel Score hazır").font(.headline)
                    Text("Maçı iPhone’dan başlat.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Sağlık izni ver") {
                        Task { _ = await workout.requestAuthorization() }
                    }
                    .font(.caption)
                }
            }
        }
        .onChange(of: store.activeMatch?.id) { _, matchID in
            if matchID == nil && workout.isRunning {
                workout.endWorkout()
            }
        }
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
        VStack(spacing: 7) {
            scoreHeader

            HStack(spacing: 6) {
                pointButton(.home, color: .cyan)
                pointButton(.away, color: .orange)
            }

            Spacer(minLength: 0)

            Button { store.undo() } label: {
                Label("Undo", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 42)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.68, green: 0.33, blue: 0.96),
                                     Color(red: 0.43, green: 0.20, blue: 0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.purple.opacity(0.35), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
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
                .font(.system(size: 22, weight: .black, design: .rounded))
            Text(match.isTieBreak
                 ? "TIE-BREAK"
                 : "\(match.completedSets.count + 1). SET  ·  OYUN \(match.currentSet.homeGames)–\(match.currentSet.awayGames)")
                .font(.system(size: 8, weight: .bold))
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
                    .padding(.top, 9)
                Spacer(minLength: 2)
                Text(match.pointLabel(for: team))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Spacer(minLength: 3)
                VStack(spacing: 3) {
                    playerRow(name: team == .home ? match.home.first : match.away.first,
                              index: team == .home ? 0 : 1)
                    playerRow(name: team == .home ? match.home.second : match.away.second,
                              index: team == .home ? 2 : 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 9)
            }.frame(maxWidth: .infinity, minHeight: 150)
        }
        .buttonStyle(.plain)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(color)
    }

    private func playerRow(name: String, index: Int) -> some View {
        HStack(spacing: 3) {
            if match.serverIndex == index {
                Image("TennisBallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
            }
            Text(name).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(.system(size: 9, weight: match.serverIndex == index ? .bold : .medium))
        .foregroundStyle(.white)
    }
}
