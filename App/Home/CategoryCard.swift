import NeuralyzerKit
import SwiftUI

/// A bold flat card with an ink outline, like a sticker: icon tile on top, name and size below.
struct CategoryCard: View {
    let result: CategoryResult
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: result.id.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 1.5))
            Spacer(minLength: 28)
            Text(result.id.title)
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text(formatBytes(result.bytes))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .monospacedDigit()
                .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.tint(for: result.id)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rotationEffect(.degrees(hovering ? -1.5 : 0))
        .offset(y: hovering ? -4 : 0)
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.08), radius: hovering ? 18 : 10, y: 8)
        .animation(.smooth(duration: 0.2), value: hovering)
        .onHover { hovering = $0 }
    }
}
