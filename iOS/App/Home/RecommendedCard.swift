import NeuralyzerPhoneKit
import SwiftUI

/// What Neuralyzer suggests deleting, at the top of Home.
struct RecommendedCard: View {
    @Environment(PhoneStore.self) private var store

    var body: some View {
        let total = store.recommended.reduce(Int64(0)) { $0 + $1.bytes }
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        NavigationLink(value: Route.recommended) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended").font(Theme.title(26)).foregroundStyle(Theme.ink)
                Text("\(aboutSize(total)) safe to delete").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.recommended.prefix(4)) { r in
                        HStack {
                            Text(r.reason).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(aboutSize(r.bytes).replacingOccurrences(of: "About ", with: "")).monospacedDigit()
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink.opacity(0.75))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.yellow))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

enum Route: Hashable { case recommended }

/// Every recommendation with its photos or files; one button deletes what is checked.
struct RecommendedView: View {
    @Environment(PhoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Recommended").font(Theme.title(34))
                        Spacer()
                        Button("Select All") { store.selectAllRecommended() }.font(.system(size: 15, weight: .semibold))
                    }
                    ForEach(store.recommended) { r in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(r.reason).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text(aboutSize(r.bytes).replacingOccurrences(of: "About ", with: "")).font(.system(size: 14)).foregroundStyle(.secondary)
                            }
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(r.ids, id: \.self) { tile($0) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            VStack(spacing: 8) {
                Button("Delete \(aboutSize(store.selectedRecommendedBytes))") { Task { await store.deleteRecommended() } }
                    .buttonStyle(InkButtonStyle())
                    .disabled(store.selectedRecommended.isEmpty)
                Text("Space frees after Recently Deleted is emptied.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .onChange(of: store.recommended.isEmpty) { _, empty in if empty { dismiss() } }
    }

    private func tile(_ id: String) -> some View {
        let selected = store.selection.contains(id)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let isFile = id.hasPrefix("/")
        return Group {
            if isFile {
                Color.white.overlay(Image(systemName: "doc").font(.system(size: 22)).foregroundStyle(Theme.ink))
            } else {
                Thumbnail(id: id)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: selected ? 3 : 1))
        .overlay(alignment: .topTrailing) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(selected ? Theme.ink : .white)
                .background(Circle().fill(selected ? .white : .black.opacity(0.2)))
                .padding(4)
        }
        .contentShape(shape)
        .onTapGesture { store.toggle(id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFile ? "File" : "Photo")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits([.isButton])
    }
}
