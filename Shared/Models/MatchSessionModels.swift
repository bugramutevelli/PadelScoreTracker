import Foundation

enum MatchSessionRole: String, Codable, Sendable {
    case solo
    case host
    case participant
}

enum MatchSessionCommand: Codable, Equatable, Sendable {
    case awardPoint(Team)
    case undo
    case finishEarly
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
