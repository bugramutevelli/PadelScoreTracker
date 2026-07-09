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
    var onMatchCleared: (() -> Void)? {
        didSet {
            guard hasPendingClear, let onMatchCleared else { return }
            hasPendingClear = false
            onMatchCleared()
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
    private var hasPendingClear = false
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

    func clearMatch() {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = ["clear": true]
        updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                pendingMatch = nil
                if let onMatchCleared {
                    onMatchCleared()
                } else {
                    hasPendingClear = true
                }
            }
            return
        }

        guard let data = payload["match"] as? Data,
              let match = try? decoder.decode(PadelMatch.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            hasPendingClear = false
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
            guard let self, let payload = pendingApplicationContext else { return }
            updateApplicationContext(payload)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
