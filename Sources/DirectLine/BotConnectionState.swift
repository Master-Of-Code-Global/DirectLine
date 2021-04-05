import Foundation

public enum BotConnectionState: Equatable {
    case uninitialized
    case connecting
    case connectingFailed
    case ready(Conversation)
    case failed(BotConnectionError)
    case tokenExpired(Conversation)
}

internal extension BotConnectionState {
    var isReadyOrHasFailed: Bool {
        switch self {
        case .ready, .failed:
            return true
        default:
            return false
        }
    }
    
    var isNeedConnect: Bool {
        switch self {
        case .uninitialized, .tokenExpired, .connectingFailed:
            return true
        default:
            return false
        }
    }

    func conversation() throws -> Conversation {
        switch self {
        case let .ready(conversation), let .tokenExpired(conversation):
            return conversation
        case let .failed(error):
            throw error
        default:
            fatalError("Unexpected connection state: \(self)")
        }
    }
}
