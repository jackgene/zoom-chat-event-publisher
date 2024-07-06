/// A single chat message
public struct ChatMessage: CustomStringConvertible {
    public let route: String
    public let text: String
    
    public var description: String {
        return "\(route): \(text)"
    }
}
