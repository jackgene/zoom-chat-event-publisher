import Foundation

/// A (possibly failed) attempt to publish a chat message to a destination service
public struct PublishAttempt {
    public let chatMessage: ChatMessage
    public let httpResponseResult: Result<HTTPURLResponse, any Error>
}
