import Foundation

/// The ZoomChatPublisher application state
public struct Model {
    public let startTime: Date = Date()
    public var status: ZoomApplicationStatus = .notRunning
    public var publishAttempts: [PublishAttempt] = []
    public var publishSuccessCount: UInt = 0
    public var publishFailureCount: UInt = 0
    
    public init() {}
}
