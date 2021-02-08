import Foundation
import SimpleNetworking

public enum BotConnectionError: Equatable, Error {
    case failedToConnect(String?)
    case tokenExpired
    case badArgument(String?)
    case conversationEnded
}

internal extension BotConnectionError {
    init(error: Error) {
        if let botConnectionError = error as? BotConnectionError {
            self = botConnectionError
        } else if let badStatusError = error as? BadStatusError, let errorResponse = badStatusError.errorResponse {
            switch errorResponse.error.code {
            case .tokenExpired:
                self = .tokenExpired
            case .badArgument:
                self = .badArgument(errorResponse.error.message)
            default:
                self = .failedToConnect(errorResponse.error.message)
            }
        } else {
            self = .failedToConnect(nil)
        }
    }
}
