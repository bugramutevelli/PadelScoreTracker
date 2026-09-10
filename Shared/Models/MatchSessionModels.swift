import Foundation

enum MatchSessionRole: String, Codable, Sendable {
    case solo
    case host
    case participant
}

enum MatchSessionAction: Codable, Equatable, Sendable {
    case awardPoint(Team)
    case undo
    case finishEarly
}

struct MatchSessionCommand: Codable, Equatable, Sendable {
    var id: UUID
    var matchID: UUID
    var action: MatchSessionAction

    static func awardPoint(_ team: Team, matchID: UUID) -> MatchSessionCommand {
        MatchSessionCommand(id: UUID(), matchID: matchID, action: .awardPoint(team))
    }

    static func undo(matchID: UUID) -> MatchSessionCommand {
        MatchSessionCommand(id: UUID(), matchID: matchID, action: .undo)
    }

    static func finishEarly(matchID: UUID) -> MatchSessionCommand {
        MatchSessionCommand(id: UUID(), matchID: matchID, action: .finishEarly)
    }
}

struct MatchSessionEnvelope: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case state
        case command
        case clear
    }

    var kind: Kind
    var match: PadelMatch?
    var command: MatchSessionCommand?
}

enum MatchSyncPolicy {
    static func shouldAccept(
        remote: PadelMatch,
        current: PadelMatch?,
        closedMatchIDs: Set<UUID>
    ) -> Bool {
        guard !closedMatchIDs.contains(remote.id) else { return false }
        guard let current else { return true }
        guard current.id == remote.id else { return false }
        return remote.syncRevision > current.syncRevision
    }
}
