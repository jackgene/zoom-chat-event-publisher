/// Is the Zoom process running?
public enum ZoomApplicationStatus {
    case running(meeting: MeetingStatus)
    case notRunning
}
