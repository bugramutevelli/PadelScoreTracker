import Foundation
import Combine
import WatchConnectivity

final class WatchSessionCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionCoordinator()
    var onMatchReceived: ((PadelMatch) -> Void)? {
        didSet {
            guard let pendingMatch, let onMatchReceived else { return }
            self.pendingMatch = nil
            onMatchReceived(pendingMatch)
        }
    }
    var onCommandReceived: ((MatchSessionCommand) -> Void)? {
        didSet {
            guard let pendingCommand, let onCommandReceived else { return }
            self.pendingCommand = nil
            onCommandReceived(pendingCommand)
        }
    }
    var onMatchCleared: ((PadelMatch?) -> Void)? {
        didSet {
            guard let pendingClearedMatch, let onMatchCleared else { return }
            self.pendingClearedMatch = nil
            onMatchCleared(pendingClearedMatch.match)
        }
    }
    var onWorkoutMetricsReceived: ((UUID, WorkoutMetrics) -> Void)? {
        didSet {
            guard let pendingWorkoutMetrics, let onWorkoutMetricsReceived else { return }
            self.pendingWorkoutMetrics = nil
            onWorkoutMetricsReceived(pendingWorkoutMetrics.matchID, pendingWorkoutMetrics.metrics)
        }
    }
    var onActiveMatchRequested: (() -> Void)? {
        didSet {
            guard hasPendingActiveMatchRequest, let onActiveMatchRequested else { return }
            hasPendingActiveMatchRequest = false
            onActiveMatchRequested()
        }
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var pendingMatch: PadelMatch?
    private var pendingCommand: MatchSessionCommand?
    private var pendingClearedMatch: PendingClearedMatch?
    private var pendingWorkoutMetrics: PendingWorkoutMetrics?
    private var hasPendingActiveMatchRequest = false
    private var pendingApplicationContext: [String: Any]?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(_ match: PadelMatch) {
        guard WCSession.isSupported() else { return }
        guard let data = try? encoder.encode(match) else { return }
        let payload: [String: Any] = ["match": data]
        updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    func clearMatch(_ match: PadelMatch) {
        guard WCSession.isSupported() else { return }
        guard let data = try? encoder.encode(match) else { return }
        let payload: [String: Any] = ["clear": true, "match": data]
        updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendWorkoutMetrics(_ metrics: WorkoutMetrics, for matchID: UUID) {
        guard WCSession.isSupported() else { return }
        guard let data = try? encoder.encode(metrics) else { return }
        let payload: [String: Any] = [
            "workoutMetrics": data,
            "matchID": matchID.uuidString
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func sendCommand(_ command: MatchSessionCommand) {
        guard WCSession.isSupported() else { return }
        guard let data = try? encoder.encode(command) else { return }
        let payload: [String: Any] = ["command": data]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func requestActiveMatch() {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = ["requestActiveMatch": true]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        receive(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        receive(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        receive(userInfo)
    }

    private func receive(_ payload: [String: Any]) {
        if payload["requestActiveMatch"] as? Bool == true {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let onActiveMatchRequested {
                    onActiveMatchRequested()
                } else {
                    hasPendingActiveMatchRequest = true
                }
            }
            return
        }

        if payload["clear"] as? Bool == true {
            let clearedMatch = (payload["match"] as? Data)
                .flatMap { try? decoder.decode(PadelMatch.self, from: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                pendingMatch = nil
                pendingCommand = nil
                if let onMatchCleared {
                    onMatchCleared(clearedMatch)
                } else {
                    pendingClearedMatch = PendingClearedMatch(match: clearedMatch)
                }
            }
            return
        }

        if let data = payload["workoutMetrics"] as? Data,
           let matchIDString = payload["matchID"] as? String,
           let matchID = UUID(uuidString: matchIDString),
           let metrics = try? decoder.decode(WorkoutMetrics.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let onWorkoutMetricsReceived {
                    onWorkoutMetricsReceived(matchID, metrics)
                } else {
                    pendingWorkoutMetrics = PendingWorkoutMetrics(matchID: matchID, metrics: metrics)
                }
            }
            return
        }

        if let data = payload["command"] as? Data,
           let command = try? decoder.decode(MatchSessionCommand.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let onCommandReceived {
                    onCommandReceived(command)
                } else {
                    pendingCommand = command
                }
            }
            return
        }

        guard let data = payload["match"] as? Data,
              let match = try? decoder.decode(PadelMatch.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let onMatchReceived {
                onMatchReceived(match)
            } else {
                pendingMatch = match
            }
        }
    }

    private func updateApplicationContext(_ payload: [String: Any]) {
        do {
            try WCSession.default.updateApplicationContext(payload)
            pendingApplicationContext = nil
        } catch {
            pendingApplicationContext = payload
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !session.receivedApplicationContext.isEmpty {
                receive(session.receivedApplicationContext)
            }
            guard let payload = pendingApplicationContext else { return }
            updateApplicationContext(payload)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

private struct PendingClearedMatch {
    let match: PadelMatch?
}

private struct PendingWorkoutMetrics {
    let matchID: UUID
    let metrics: WorkoutMetrics
}
