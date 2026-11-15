import SwiftUI

enum Crayon {
    static let ink = Color(red: 0.29, green: 0.23, blue: 0.20)
    static let paper = Color(red: 1.00, green: 0.97, blue: 0.89)
    static let green = Color(red: 0.18, green: 0.39, blue: 0.29)
    static let yellow = Color(red: 1.00, green: 0.88, blue: 0.59)
    static let peach = Color(red: 1.00, green: 0.85, blue: 0.76)
    static let blue = Color(red: 0.83, green: 0.92, blue: 0.96)
    static let pink = Color(red: 0.98, green: 0.85, blue: 0.87)
}

struct PaperBackground: View {
    var body: some View {
        Crayon.paper.overlay {
            Canvas { context, size in
                for row in stride(from: 0, through: Int(size.height), by: 22) {
                    for column in stride(from: 0, through: Int(size.width), by: 25) {
                        let x = CGFloat(column + (row % 7))
                        let y = CGFloat(row)
                        let line = Path { p in p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 4, y: y + 1)) }
                        context.stroke(line, with: .color(Crayon.ink.opacity(0.045)), lineWidth: 1)
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }.ignoresSafeArea()
    }
}

struct CrayonCard: ViewModifier {
    var color: Color
    func body(content: Content) -> some View {
        content.background(color, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Crayon.ink.opacity(0.65), lineWidth: 1.8))
            .overlay(RoundedRectangle(cornerRadius: 19).inset(by: 4).stroke(Crayon.ink.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [7, 4, 2, 3])))
            .shadow(color: Crayon.ink.opacity(0.10), radius: 0, x: 1, y: 4)
    }
}
extension View {
    func crayonCard(_ color: Color = .white) -> some View { modifier(CrayonCard(color: color)) }
}
struct CrayonButtonStyle: ButtonStyle {
    var color: Color = Crayon.yellow
    var ink: Color = Crayon.ink
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded).weight(.bold))
            .foregroundStyle(ink).padding(.horizontal, 15).padding(.vertical, 12)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.75), lineWidth: 1.7))
            .shadow(color: ink.opacity(0.16), radius: 0, x: 0, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.48)
    }
}
