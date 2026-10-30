import NeuralyzerKit
import SwiftUI

struct CategoryCard: View {
    let result: CategoryResult
    @State private var hovering = false

    var body: some View {
        let tint = Theme.tint(for: result.id)
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: result.id.symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint.mix(with: .black, by: 0.45))
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.7)))
            Spacer(minLength: 28)
            Text(result.id.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            Text(formatBytes(result.bytes))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(
            FolderShape()
                .fill(LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.28)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(FolderShape().stroke(.white.opacity(0.6), lineWidth: 1))
        .contentShape(FolderShape())
        .scaleEffect(hovering ? 1.015 : 1)
        .shadow(color: .black.opacity(hovering ? 0.08 : 0.04), radius: hovering ? 18 : 10, y: 6)
        .animation(.smooth(duration: 0.2), value: hovering)
        .onHover { hovering = $0 }
    }
}
