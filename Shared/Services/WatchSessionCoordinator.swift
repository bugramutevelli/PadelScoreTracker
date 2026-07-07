import Foundation
import Combine
import WatchConnectivity

final class WatchSessionCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionCoordinator()
    var onMatchReceived: ((PadelMatch) -> Void)?
    var onMatchCleared: (() -> Void)?
    var onActiveMatchRequested: (() -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    func clearMatch() {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = ["clear": true]
        try? WCSession.default.updateApplicationContext(payload)
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
            DispatchQueue.main.async { [weak self] in self?.onActiveMatchRequested?() }
            return
        }

        if payload["clear"] as? Bool == true {
            DispatchQueue.main.async { [weak self] in self?.onMatchCleared?() }
            return
        }

        guard let data = payload["match"] as? Data,
              let match = try? decoder.decode(PadelMatch.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.onMatchReceived?(match) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
