import NeuralyzerPhoneKit
import SwiftUI

/// A bold flat card with an ink outline: icon tile, serif name, size or count.
struct CategoryCard: View {
    @Environment(PhoneStore.self) private var store
    let category: PhoneCategory

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let tile = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: category.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(tile.fill(.white))
                .overlay(tile.strokeBorder(Theme.ink, lineWidth: 1.5))
            Spacer(minLength: 22)
            Text(category.title)
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(shape.fill(Theme.tint(for: category)))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
    }

    private var detail: String {
        guard let content = store.results[category] else { return "" }
        if category == .contacts {
            let n = content.contactGroups.reduce(0) { $0 + $1.others.count + 1 }
            return "\(n) contacts"
        }
        let bytes = content.bytes
        return category == .icloudDuplicates || category == .icloudLarge ? formatted(bytes) : aboutSize(bytes)
    }
}
