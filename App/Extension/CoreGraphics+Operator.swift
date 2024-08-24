import CoreGraphics

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        .init(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
    
    static func - (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        .init(x: lhs.x - rhs.dx, y: lhs.y - rhs.dy)
    }
}

extension CGSize {
    static func + (lhs: CGSize, rhs: CGVector) -> CGSize {
        .init(width: lhs.width + rhs.dx, height: lhs.height + rhs.dy)
    }
}
