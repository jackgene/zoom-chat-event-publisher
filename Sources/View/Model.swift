import Foundation

/// The ZoomChatPublisher application state
struct Model {
    let startTime: Date = Date()
    var status: ZoomApplicationStatus = .notRunning
    var publishAttempts: [PublishAttempt] = []
    var publishSuccessCount: UInt = 0
    var publishFailureCount: UInt = 0
}
