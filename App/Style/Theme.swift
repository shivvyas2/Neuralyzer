import NeuralyzerKit
import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
        startPoint: .top, endPoint: .bottom
    )

    /// Bold flat colors, one per kind of clutter. Text and outlines on them are always ink.
    static let lavender = Color(red: 0.776, green: 0.714, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.784, blue: 0.239)
    static let pink = Color(red: 0.961, green: 0.651, blue: 0.824)
    static let green = Color(red: 0.247, green: 0.82, blue: 0.498)
    static let blue = Color(red: 0.431, green: 0.616, blue: 0.969)
    static let coral = Color(red: 0.937, green: 0.522, blue: 0.341)
    static let stone = Color(red: 0.85, green: 0.85, blue: 0.87)
    static let ink = Color(red: 0.122, green: 0.122, blue: 0.141)

    static func tint(for category: CategoryID) -> Color {
        switch category {
        case .xcode: yellow
        case .simulators: lavender
        case .claudeCode: pink
        case .packageCaches: green
        case .projectBuilds: blue
        case .vms: lavender
        case .appCaches: coral
        case .junk: pink
        case .trash: stone
        case .largeFiles: blue
        case .oldFiles: yellow
        }
    }

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
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
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color("Surface")))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.85), lineWidth: 1.5))
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
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color("Pill")))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
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
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color("Surface")))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.15), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
