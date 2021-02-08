import Combine
import Foundation
import Logging
import SimpleNetworking

public class BotConnection<ChannelData> where ChannelData: Codable, ChannelData: Equatable {
    public typealias ActivityStream = Publishers.Share<Publishers.FlatMap<Publishers.Sequence<[Activity<ChannelData>], Error>,
                                                                          AnyPublisher<ActivityGroup<ChannelData>, Error>>>
    
    public var state: AnyPublisher<BotConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public private(set) lazy var activities = conversation()
        .activityStream(ChannelData.self, logLevel: logger.logLevel)
        .flatMap { Publishers.Sequence(sequence: $0.activities) }
        .share()

    private let auth: Auth
    private let apiClient: APIClient
    private let stateSubject = CurrentValueSubject<BotConnectionState, Never>(.uninitialized)
    private let syncQueue = DispatchQueue(label: "com.gonzalezreal.DirectLine.BotConnection")
    private var logger = Logger(label: "BotConnection")

    public init(_ auth: Auth, logLevel: Logger.Level) {
        self.auth = auth
        apiClient = APIClient(baseURL: .directLine, logLevel: logLevel)
        logger.logLevel = logLevel
    }
    
    public func getActivityStream() -> ActivityStream {
        conversation()
            .activityStream(ChannelData.self, logLevel: logger.logLevel)
            .flatMap { Publishers.Sequence(sequence: $0.activities) }
            .share()
    }
    
    public func resetState() {
        switch stateSubject.value {
        case let .ready(conversation), let .tokenExpired(conversation):
            stateSubject.send(.tokenExpired(conversation))
        default: break
        }
    }

    /// Send an activity to the bot.
    /// - Parameter activity: Activity to send.
    public func postActivity(_ activity: Activity<ChannelData>) -> AnyPublisher<ResourceResponse, BotConnectionError> {
        // Get the current conversation or start one if necessary
        conversation().first()
            .flatMap { [apiClient] conversation -> AnyPublisher<ResourceResponse, BotConnectionError> in
                // Post the activity in the conversation
                apiClient.response(for: .postActivity(token: conversation.token, conversationId: conversation.conversationId, activity: activity))
                    .mapError {
                        let error = BotConnectionError(error: $0)
                        if error == .tokenExpired {
                            self.stateSubject.send(.tokenExpired(conversation))
                        }
                        return error
                    }
                    .eraseToAnyPublisher()
            }
            .retry(1) { error in
                return error == .tokenExpired
            }
            .eraseToAnyPublisher()
    }
}

private extension BotConnection {
    /// Return the current conversation or start one if necessary.
    func conversation() -> AnyPublisher<Conversation, BotConnectionError> {
        stateSubject
            .setFailureType(to: BotConnectionError.self)
            .receive(on: syncQueue)
            .flatMap { [weak self] connectionState -> AnyPublisher<BotConnectionState, BotConnectionError> in
                // Start a new conversation if necessary of reconnect
                guard let self = self, connectionState.isNeedConnect else {
                    return Just(connectionState)
                        .setFailureType(to: BotConnectionError.self)
                        .eraseToAnyPublisher()
                }

                // Let subscribers know that we are connecting
                self.stateSubject.send(.connecting)

                let publisher: AnyPublisher<Conversation, BotConnectionError>
                if case let .tokenExpired(conversation) = connectionState {
                    publisher = self.restartConversation(conversation.conversationId)
                } else {
                    publisher = self.startConversation()
                }

                return publisher
                    .map { BotConnectionState.ready($0) }
                    // Let subscribers know that we are ready
                    .handleEvents(receiveOutput: { self.stateSubject.send($0) })
                    .eraseToAnyPublisher()
            }
            .filter { $0.isReadyOrHasFailed }
            .tryMap { try $0.conversation() }
            .mapError { BotConnectionError(error: $0) }
            .eraseToAnyPublisher()
    }

    /// Start a new conversation.
    func startConversation() -> AnyPublisher<Conversation, BotConnectionError> {
        apiClient.response(for: .startConversation(auth))
            .mapError { BotConnectionError(error: $0) }
            .receive(on: syncQueue)
            .eraseToAnyPublisher()
    }
    
    func restartConversation(_ conversationId: String) -> AnyPublisher<Conversation, BotConnectionError> {
        apiClient.response(for: .conversation(auth, conversationId: conversationId))
            .mapError { BotConnectionError(error: $0) }
            .receive(on: syncQueue)
            .eraseToAnyPublisher()
    }
}
