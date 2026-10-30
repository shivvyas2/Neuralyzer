import NeuralyzerKit
import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
        startPoint: .top, endPoint: .bottom
    )

    static func tint(for category: CategoryID) -> Color {
        switch category {
        case .xcode: Color(red: 0.55, green: 0.72, blue: 0.98)
        case .simulators: Color(red: 0.70, green: 0.66, blue: 0.96)
        case .claudeCode: Color(red: 0.98, green: 0.74, blue: 0.58)
        case .packageCaches: Color(red: 0.60, green: 0.85, blue: 0.78)
        case .projectBuilds: Color(red: 0.62, green: 0.80, blue: 0.95)
        case .vms: Color(red: 0.78, green: 0.74, blue: 0.90)
        case .appCaches: Color(red: 0.95, green: 0.80, blue: 0.62)
        case .junk: Color(red: 0.92, green: 0.70, blue: 0.74)
        case .trash: Color(red: 0.75, green: 0.78, blue: 0.82)
        case .largeFiles: Color(red: 0.66, green: 0.82, blue: 0.70)
        case .oldFiles: Color(red: 0.88, green: 0.82, blue: 0.62)
        }
    }
}

/// A card shaped like a folder: a short tab on the top left above a rounded body.
struct FolderShape: Shape {
    var radius: CGFloat = 20
    var tabWidth: CGFloat = 0.38
    var tabHeight: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let r = radius
        let tabW = rect.width * tabWidth
        let top = rect.minY + tabHeight
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + tabW - 12, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX + tabW + 12, y: top),
                   control1: CGPoint(x: rect.minX + tabW, y: rect.minY),
                   control2: CGPoint(x: rect.minX + tabW, y: top))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: top))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + r), control: CGPoint(x: rect.maxX, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The plain white surface every row and panel sits on.
struct Surface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color("Surface")))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.06)))
    }
}

extension View {
    func surface() -> some View { modifier(Surface()) }
}

/// Black pill button, like the selected tab in the reference.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color("PillText"))
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color("Pill")))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
    }
}

/// Quiet outlined pill for secondary actions.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color("Surface")))
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
