import NeuralyzerPhoneKit
import SwiftUI

/// The same palette and type as Neuralyzer for Mac and the website.
enum Theme {
    static let lavender = Color(red: 0.776, green: 0.714, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.784, blue: 0.239)
    static let pink = Color(red: 0.961, green: 0.651, blue: 0.824)
    static let green = Color(red: 0.247, green: 0.82, blue: 0.498)
    static let blue = Color(red: 0.431, green: 0.616, blue: 0.969)
    static let coral = Color(red: 0.937, green: 0.522, blue: 0.341)
    static let stone = Color(red: 0.85, green: 0.85, blue: 0.87)
    static let ink = Color(red: 0.122, green: 0.122, blue: 0.141)

    static func tint(for category: PhoneCategory) -> Color {
        switch category {
        case .duplicates: yellow
        case .screenshots: lavender
        case .screenRecordings: pink
        case .bursts: green
        case .blurry: stone
        case .bigVideos: blue
        case .whatsapp: green
        case .icloudDuplicates: blue
        case .icloudLarge: lavender
        case .contacts: coral
        }
    }

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}

/// Black rounded button, like the Mac app and the site.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.ink.opacity(0.2), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The app's mark: three outlined cards fanned out, with a check on the front one.
struct AppMark: View {
    var size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            card(Theme.lavender).rotationEffect(.degrees(-16), anchor: .bottom).offset(x: -size * 0.16)
            card(Theme.blue).rotationEffect(.degrees(16), anchor: .bottom).offset(x: size * 0.16)
            card(Theme.yellow)
                .overlay {
                    let tile = RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.1, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .frame(width: size * 0.17, height: size * 0.17)
                        .background(tile.fill(.white))
                        .overlay(tile.strokeBorder(Theme.ink, lineWidth: max(1.2, size * 0.015)))
                }
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size * 0.82)
    }

    private func card(_ color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
        return shape.fill(color)
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: max(1.5, size * 0.03)))
            .frame(width: size * 0.44, height: size * 0.6)
    }
}
