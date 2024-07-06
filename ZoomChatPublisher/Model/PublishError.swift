/// Application error
public enum PublishError: Error {
    case zoomNotRunning
    case noMeetingInProgress
    case chatNotOpen
}
