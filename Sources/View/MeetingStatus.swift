/// Is a meeting ongoing?
enum MeetingStatus {
    case inProgress(chatOpen: Bool)
    case notInProgress
}
