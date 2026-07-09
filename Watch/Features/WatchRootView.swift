import SwiftUI
import WatchKit

struct WatchRootView: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var workout: WorkoutManager
    @State private var isShowingMatch = false

    var body: some View {
        Group {
            if isShowingMatch, let match = store.activeMatch {
                WatchMatchView(match: match)
            } else {
                WatchQuickStartView(
                    hasActiveMatch: store.activeMatch != nil,
                    onContinueMatch: { isShowingMatch = true }
                )
            }
        }
        .onChange(of: store.activeMatch?.id) { matchID in
            if matchID != nil {
                isShowingMatch = true
            } else {
                isShowingMatch = false
                if workout.isRunning {
                    workout.endWorkout()
                }
            }
        }
        .task {
            if store.activeMatch != nil {
                isShowingMatch = true
            }
            store.requestActiveMatch()
        }
    }
}

private struct WatchQuickStartView: View {
    let hasActiveMatch: Bool
    let onContinueMatch: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                WatchPadelMarkIcon()
                    .frame(width: 45, height: 45)

                Text("Padel Score")
                    .font(.headline)

                NavigationLink {
                    WatchQuickMatchSetupView(onStartMatch: onContinueMatch)
                } label: {
                    Label("Hızlı Maç Başlat", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.75, green: 0.96, blue: 0.25))
                .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.02))

                if hasActiveMatch {
                    Button(action: onContinueMatch) {
                        Label("Maça Devam Et", systemImage: "arrow.forward.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct WatchQuickMatchSetupView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    let onStartMatch: () -> Void
    @State private var format: MatchFormat = .bestOfThree
    @State private var rule: ScoringRule = .advantage
    @State private var firstServerIndex = 0

    private let serverNames = [
        TeamPlayers.homeDefault.first,
        TeamPlayers.awayDefault.first,
        TeamPlayers.homeDefault.second,
        TeamPlayers.awayDefault.second
    ]

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

                Picker("İlk servis", selection: $firstServerIndex) {
                    ForEach(serverNames.indices, id: \.self) { index in
                        Text(serverNames[index]).tag(index)
                    }
                }
            }

            Button {
                store.start(
                    home: .homeDefault,
                    away: .awayDefault,
                    rule: rule,
                    format: format,
                    firstServerIndex: firstServerIndex
                )
                dismiss()
                onStartMatch()
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

private struct WatchPadelMarkIcon: View {
    var body: some View {
        ZStack {
            racket
                .rotationEffect(.degrees(-22))
                .offset(x: -4, y: -3)

            ball
                .frame(width: 17, height: 17)
                .offset(x: 12, y: 12)
        }
        .shadow(color: .black.opacity(0.36), radius: 7, y: 4)
        .accessibilityHidden(true)
    }

    private var racket: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.97, blue: 1.0),
                            Color(red: 0.45, green: 0.52, blue: 0.60),
                            Color(red: 0.12, green: 0.15, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 32)
                .overlay(
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [.white, Color(red: 0.55, green: 0.62, blue: 0.70)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )

            Ellipse()
                .fill(Color(red: 0.06, green: 0.09, blue: 0.14).opacity(0.72))
                .frame(width: 16, height: 23)

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    hole
                    hole
                    hole
                }
                HStack(spacing: 4) {
                    hole
                    hole
                    hole
                }
                HStack(spacing: 4) {
                    hole
                    hole
                }
            }
            .offset(y: -2)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.86, green: 0.90, blue: 0.94))
                .frame(width: 7, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.16))
                        .frame(width: 4, height: 15)
                )
                .offset(y: 24)
        }
    }

    private var hole: some View {
        Circle()
            .fill(Color(red: 0.56, green: 0.63, blue: 0.70))
            .frame(width: 2.5, height: 2.5)
    }

    private var ball: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 1.0, blue: 0.54),
                            Color(red: 0.78, green: 0.96, blue: 0.24),
                            Color(red: 0.56, green: 0.79, blue: 0.09)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 17
                    )
                )
                .overlay(Circle().stroke(Color(red: 0.92, green: 1.0, blue: 0.47), lineWidth: 1.4))

            Capsule()
                .stroke(Color(red: 0.49, green: 0.67, blue: 0.08), lineWidth: 1.2)
                .frame(width: 15, height: 3)
                .rotationEffect(.degrees(-24))
                .offset(y: -3)

            Capsule()
                .stroke(Color(red: 0.49, green: 0.67, blue: 0.08), lineWidth: 1.2)
                .frame(width: 15, height: 3)
                .rotationEffect(.degrees(24))
                .offset(y: 3)
        }
    }
}

private struct WatchMatchView: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var workout: WorkoutManager
    let match: PadelMatch
    @State private var isWinnerCelebrationVisible = false

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
        .onChange(of: Int(workout.metrics.duration / 15)) { _ in
            store.updateWorkoutMetrics(workout.metrics)
        }
        .onChange(of: match.isFinished) { finished in
            guard finished else { return }
            store.updateWorkoutMetrics(workout.metrics)
            workout.endWorkout()
        }
        .onChange(of: workout.isRunning) { running in
            if !running { store.updateWorkoutMetrics(workout.metrics) }
        }
        .onChange(of: store.activeMatch?.winner) { winner in
            isWinnerCelebrationVisible = winner != nil
        }
        .onAppear {
            isWinnerCelebrationVisible = store.activeMatch?.winner != nil
        }
        .overlay {
            if isWinnerCelebrationVisible,
               let activeMatch = store.activeMatch,
               let winner = activeMatch.winner {
                ZStack {
                    Color.black.opacity(0.76)

                    WatchWinnerCelebration(teamName: activeMatch.teamName(winner))
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isWinnerCelebrationVisible = false
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var scoreboardPage: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                scoreHeader

                HStack(spacing: 6) {
                    pointButton(.home, color: .cyan)
                    pointButton(.away, color: .orange)
                }
                .frame(maxWidth: 178)

                undoButton

                Spacer()
                    .frame(height: 6)

                finishButton
            }
            .frame(maxWidth: .infinity)
            .padding(.top, -24)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private var scoreHeader: some View {
        let liveMatch = store.activeMatch ?? match

        return ZStack(alignment: .leading) {
            VStack(spacing: -1) {
                Text("SETLER")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.secondary)
                Text("\(liveMatch.homeSets)–\(liveMatch.awaySets)")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                Text(liveMatch.isTieBreak
                     ? "TIE-BREAK"
                     : "\(liveMatch.completedSets.count + 1). SET  ·  OYUN \(liveMatch.currentSet.homeGames)–\(liveMatch.currentSet.awayGames)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(workoutDuration)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.yellow)
            .frame(width: 58, alignment: .leading)
        }
        .lineLimit(1)
    }

    private var undoButton: some View {
        Button { store.undo() } label: {
            Label("Undo", systemImage: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 132, height: 34)
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

    private var finishButton: some View {
        Button { finishMatch() } label: {
            Text("Bitir")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 132, height: 34)
                .background(Color.red.opacity(0.88), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.7))
        }
        .buttonStyle(WatchUndoButtonStyle())
    }

    private var workoutPage: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 12, weight: .bold))
                    Text("PADEL")
                        .font(.system(size: 12, weight: .black))
                    Spacer()
                    Circle()
                        .fill(workout.isRunning ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                }
                .foregroundStyle(.green)
                .padding(.bottom, 1)

                workoutMetric("SÜRE", workoutDuration, .yellow, size: 34)
                workoutMetric("AKTİF KALORİ", "\(Int(workout.metrics.activeCalories)) KCAL", .pink, size: 27)
                workoutMetric("NABIZ", heartRateText, .red, size: 27)
                workoutMetric("MESAFE", String(format: "%.2f KM", workout.metrics.distanceMeters / 1000), .cyan, size: 27)
                workoutMetric("ADIM", "\(workout.metrics.steps)", .green, size: 27)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
        }
        .scrollIndicators(.hidden)
    }

    private var workoutDuration: String {
        let total = Int(workout.metrics.duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var heartRateText: String {
        workout.metrics.heartRate > 0 ? "\(Int(workout.metrics.heartRate)) BPM" : "-- BPM"
    }

    private func workoutMetric(_ title: String, _ value: String, _ color: Color, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func finishMatch() {
        store.updateWorkoutMetrics(workout.metrics)
        store.finishEarly()
    }

    private func pointButton(_ team: Team, color: Color) -> some View {
        Button { awardPoint(to: team) } label: {
            VStack(spacing: 5) {
                Text(team == .home ? "TAKIM A" : "TAKIM B")
                    .font(.system(size: 9, weight: .black))
                    .padding(.top, 9)
                Text(match.pointLabel(for: team))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .monospacedDigit()
                VStack(spacing: 2) {
                    playerRow(name: team == .home ? match.home.first : match.away.first,
                              index: team == .home ? 0 : 1)
                    playerRow(name: team == .home ? match.home.second : match.away.second,
                              index: team == .home ? 2 : 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 3)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .buttonStyle(WatchScoreButtonStyle(color: color))
    }

    private func awardPoint(to team: Team) {
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
        WKInterfaceDevice.current().play(.directionUp)
        guard gameCompleted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func playerRow(name: String, index: Int) -> some View {
        let isServing = match.serverIndex == index

        return HStack(spacing: 3) {
            if isServing {
                Image("TennisBallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 9, height: 9)
            }
            Text(name).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(.system(size: 9, weight: isServing ? .bold : .semibold, design: .rounded))
        .foregroundStyle(isServing
                         ? Color(red: 0.88, green: 1, blue: 0.58)
                         : Color.white.opacity(0.86))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
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

private struct WatchWinnerCelebration: View {
    let teamName: String

    @State private var ballOffset: CGFloat = -130
    @State private var ballScale: CGFloat = 0.8
    @State private var trailOpacity = 0.9
    @State private var isWinnerVisible = false
    @State private var isConfettiVisible = false

    var body: some View {
        ZStack {
            if isConfettiVisible {
                WatchConfettiBurst()
            }

            VStack(spacing: 7) {
                ZStack {
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(Color(red: 0.75, green: 0.96, blue: 0.25)
                                    .opacity(0.12 + Double(index) * 0.14))
                                .frame(width: CGFloat(9 + index * 4), height: 3)
                        }
                    }
                    .offset(x: ballOffset - 35)
                    .opacity(trailOpacity)

                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.24))
                        .shadow(color: Color.green.opacity(0.7), radius: 8)
                        .scaleEffect(ballScale)
                        .offset(x: ballOffset)
                }
                .frame(height: 38)

                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                    Text("Kazanan")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(teamName)
                        .font(.caption.bold())
                        .multilineTextAlignment(.center)
                }
                .opacity(isWinnerVisible ? 1 : 0)
                .scaleEffect(isWinnerVisible ? 1 : 0.86)
            }
            .padding()
        }
        .task {
            withAnimation(.easeOut(duration: 0.42)) {
                ballOffset = 0
                trailOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.spring(response: 0.28, dampingFraction: 0.42)) {
                ballScale = 1.3
            }

            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                ballScale = 1
                isWinnerVisible = true
            }
            isConfettiVisible = true
        }
    }
}

private struct WatchConfettiBurst: View {
    @State private var isBursting = false

    private let colors: [Color] = [.cyan, .yellow, .green, .orange, .pink, .purple]

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let angle = Double(index) * (.pi * 2 / 24) + Double(index % 3) * 0.12
                let distance = CGFloat(48 + (index % 5) * 8)

                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 2) ? 4 : 3, height: 7)
                    .rotationEffect(.degrees(isBursting ? Double(index * 37) : 0))
                    .offset(
                        x: isBursting ? CGFloat(cos(angle)) * distance : 0,
                        y: isBursting ? CGFloat(sin(angle)) * distance : 0
                    )
                    .opacity(isBursting ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.15)) {
                isBursting = true
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
}

#Preview("Watch - Mac") {
    WatchRootView()
        .environmentObject(MatchStore.preview(active: true, scored: true))
        .environmentObject(WorkoutManager.preview())
}
