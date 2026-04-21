import SwiftUI
struct RoundedCorner: Shape {
    var radius: CGFloat = 12
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct CustomCorners: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            // Start at top-left corner, just after the top-left arc
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
            // Top-left corner
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY + topLeft), radius: topLeft)
            // Bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY), radius: bottomLeft)
            // Bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight), radius: bottomRight)
            // Top-right corner
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + topRight))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX - topRight, y: rect.minY), radius: topRight)
            // Close the path
            path.closeSubpath()
        }
    }
}
