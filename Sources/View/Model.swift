/// The ZoomChatPublisher application state
struct Model {
    init(status: ZoomApplicationStatus, publishAttempts: [PublishAttempt]) {
        self.status = status
        self.publishAttempts = publishAttempts
    }
    
    init() {
        self.status = .notRunning
        self.publishAttempts = []
    }
    
    let status: ZoomApplicationStatus
    let publishAttempts: [PublishAttempt]
}
