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
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Text("Set \(match.homeSets)–\(match.awaySets)")
                    Spacer()
                    Text("Oyun \(match.currentSet.homeGames)–\(match.currentSet.awayGames)")
                }.font(.caption2).lineLimit(1)

                HStack(spacing: 6) {
                    pointButton(.home, color: .cyan)
                    pointButton(.away, color: .orange)
                }

                HStack {
                    Button { store.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.headline.bold())
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(match.history.isEmpty)
                    Text(match.decidingPointLabel ?? (match.isTieBreak ? "TIE-BREAK" : match.receivingSide))
                        .font(.caption2).foregroundStyle(.secondary)
                }

                healthGrid
            }
        }
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

    private var healthGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 5) {
            metric("flame.fill", "\(Int(workout.metrics.activeCalories)) kcal", .orange)
            metric("clock.fill", "\(Int(workout.metrics.duration) / 60) dk", .cyan)
            metric("figure.walk", "\(workout.metrics.steps) adım", .green)
            metric("location.fill", String(format: "%.2f km", workout.metrics.distanceMeters / 1000), .blue)
        }
    }

    private func metric(_ icon: String, _ value: String, _ color: Color) -> some View {
        Label(value, systemImage: icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }

    private func pointButton(_ team: Team, color: Color) -> some View {
        Button { store.awardPoint(to: team) } label: {
            VStack(spacing: 4) {
                Text(team == .home ? "TAKIM A" : "TAKIM B").font(.caption2.bold())
                Text(match.pointLabel(for: team))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                playerRow(name: team == .home ? match.home.first : match.away.first,
                          index: team == .home ? 0 : 1)
                playerRow(name: team == .home ? match.home.second : match.away.second,
                          index: team == .home ? 2 : 3)
            }.frame(maxWidth: .infinity, minHeight: 116)
        }
        .buttonStyle(.plain)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(color)
    }

    private func playerRow(name: String, index: Int) -> some View {
        HStack(spacing: 3) {
            if match.serverIndex == index {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }
            Text(name).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(.system(size: 9, weight: match.serverIndex == index ? .bold : .medium))
        .foregroundStyle(.white)
    }
}
