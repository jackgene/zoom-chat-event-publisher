/// Application error
enum PublishError: Error {
    case zoomNotRunning
    case noMeetingInProgress
    case chatNotOpen
}
