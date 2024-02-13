enum PublishEvent {
    case publish(attempt: PublishAttempt)
    case noOp
}
