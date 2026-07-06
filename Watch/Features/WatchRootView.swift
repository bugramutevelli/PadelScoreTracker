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
                scoreHeader

                HStack(spacing: 6) {
                    pointButton(.home, color: .cyan)
                    pointButton(.away, color: .orange)
                }

                Button { store.undo() } label: {
                    Label("GERİ AL", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(match.history.isEmpty)
                .opacity(match.history.isEmpty ? 0.45 : 1)

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

    private var scoreHeader: some View {
        HStack(spacing: 6) {
            scoreSummary(title: "SETLER", value: "\(match.homeSets)–\(match.awaySets)")
            scoreSummary(title: "OYUNLAR · S\(match.completedSets.count + 1)",
                         value: "\(match.currentSet.homeGames)–\(match.currentSet.awayGames)")
        }
    }

    private func scoreSummary(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity, minHeight: 39)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))
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
            }.frame(maxWidth: .infinity, minHeight: 126)
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
                    .foregroundStyle(.green)
            }
            Text(name).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(.system(size: 9, weight: match.serverIndex == index ? .bold : .medium))
        .foregroundStyle(.white)
    }
}
