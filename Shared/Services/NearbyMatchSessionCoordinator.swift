#if os(iOS)
import Foundation
import MultipeerConnectivity
import UIKit

final class NearbyMatchSessionCoordinator: NSObject, ObservableObject {
    static let shared = NearbyMatchSessionCoordinator()

    @Published private(set) var role: MatchSessionRole = .solo
    @Published private(set) var matchCode: String?
    @Published private(set) var connectedPeerNames: [String] = []
    @Published private(set) var isSearching = false
    @Published private(set) var statusText = "Tek cihaz"
    @Published private(set) var errorMessage: String?

    var onMatchReceived: ((PadelMatch) -> Void)?
    var onCommandReceived: ((MatchSessionCommand) -> Void)?
    var onCleared: (() -> Void)?
    var onPeerConnected: (() -> Void)?

    private static let serviceType = "ralli-padel"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let localPeer = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitedPeerIDs: Set<MCPeerID> = []

    private override init() {
        super.init()
        session.delegate = self
    }

    func startHosting(matchCode: String, match: PadelMatch) {
        stop()
        let normalizedCode = Self.normalize(matchCode)
        guard normalizedCode.count == 6 else {
            errorMessage = "6 haneli maç kodu gerekli."
            statusText = "Maça katılınamadı"
            return
        }
        role = .host
        self.matchCode = normalizedCode
        statusText = "Kod \(normalizedCode) ile paylaşım açık"

        advertiser = MCNearbyServiceAdvertiser(
            peer: localPeer,
            discoveryInfo: ["matchCode": normalizedCode],
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        broadcast(match)
    }

    func join(matchCode: String) {
        stop()
        let normalizedCode = Self.normalize(matchCode)
        guard normalizedCode.count == 6 else {
            errorMessage = "6 haneli maç kodu gerekli."
            statusText = "Maça katılınamadı"
            return
        }
        role = .participant
        self.matchCode = normalizedCode
        isSearching = true
        statusText = "\(normalizedCode) kodlu maç aranıyor"

        browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil

        session.disconnect()
        session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        role = .solo
        matchCode = nil
        connectedPeerNames = []
        isSearching = false
        invitedPeerIDs = []
        statusText = "Tek cihaz"
        errorMessage = nil
    }

    func broadcast(_ match: PadelMatch) {
        send(MatchSessionEnvelope(kind: .state, match: match, command: nil), to: session.connectedPeers)
    }

    func sendCommand(_ command: MatchSessionCommand) {
        guard !session.connectedPeers.isEmpty else {
            errorMessage = "Host bağlantısı bekleniyor."
            return
        }
        send(MatchSessionEnvelope(kind: .command, match: nil, command: command), to: session.connectedPeers)
    }

    func clear() {
        send(MatchSessionEnvelope(kind: .clear, match: nil, command: nil), to: session.connectedPeers)
        stop()
    }

    static func makeMatchCode() -> String {
        String(format: "%06d", Int.random(in: 100_000...999_999))
    }

    private static func normalize(_ code: String) -> String {
        code.filter(\.isNumber).prefix(6).map(String.init).joined()
    }

    private func invite(_ peerID: MCPeerID) {
        guard let matchCode, let context = matchCode.data(using: .utf8) else { return }
        browser?.invitePeer(peerID, to: session, withContext: context, timeout: 12)
    }

    private func send(_ envelope: MatchSessionEnvelope, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        do {
            let data = try encoder.encode(envelope)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }

    private func receive(_ envelope: MatchSessionEnvelope) {
        switch envelope.kind {
        case .state:
            guard let match = envelope.match else { return }
            onMatchReceived?(match)
        case .command:
            guard role == .host, let command = envelope.command else { return }
            onCommandReceived?(command)
        case .clear:
            onCleared?()
        }
    }

    private func updateConnectedPeers() {
        connectedPeerNames = session.connectedPeers.map(\.displayName).sorted()
        switch role {
        case .solo:
            statusText = "Tek cihaz"
        case .host:
            let code = matchCode ?? ""
            statusText = connectedPeerNames.isEmpty ? "Kod \(code) ile paylaşım açık" : "\(connectedPeerNames.count) cihaz bağlı"
        case .participant:
            isSearching = connectedPeerNames.isEmpty
            statusText = connectedPeerNames.isEmpty ? "\(matchCode ?? "") kodlu maç aranıyor" : "Host'a bağlı"
        }
    }
}

extension NearbyMatchSessionCoordinator: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let incomingCode = context.flatMap { String(data: $0, encoding: .utf8) }
        let shouldAccept = role == .host && incomingCode == matchCode
        invitationHandler(shouldAccept, shouldAccept ? session : nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.statusText = "Paylaşım başlatılamadı"
        }
    }
}

extension NearbyMatchSessionCoordinator: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard role == .participant,
              connectedPeerNames.isEmpty,
              !invitedPeerIDs.contains(peerID),
              info?["matchCode"] == matchCode else { return }
        invitedPeerIDs.insert(peerID)
        invite(peerID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
            self.errorMessage = error.localizedDescription
            self.statusText = "Maç aranamadı"
        }
    }
}

extension NearbyMatchSessionCoordinator: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.updateConnectedPeers()
            if state == .connected, self.role == .participant {
                self.browser?.stopBrowsingForPeers()
                self.isSearching = false
            }
            if state == .connected, self.role == .host {
                self.onPeerConnected?()
            }
            if state == .notConnected {
                self.invitedPeerIDs.remove(peerID)
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let envelope = try? decoder.decode(MatchSessionEnvelope.self, from: data) else { return }
        DispatchQueue.main.async { self.receive(envelope) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
#endif
