/// Is a meeting ongoing?
public enum MeetingStatus {
    case inProgress(chatOpen: Bool)
    case notInProgress
}
