/// Is the Zoom process running?
enum ZoomApplicationStatus {
    case running(meeting: MeetingStatus)
    case notRunning
}
