import NeuralyzerPhoneKit
import SwiftUI

struct FileListView: View {
    @Environment(PhoneStore.self) private var store
    let content: CategoryContent

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(content.fileGroups, id: \.keep.id) { group in
                VStack(spacing: 6) {
                    row(group.keep, keep: true)
                    ForEach(group.others) { row($0, keep: false) }
                }
            }
            ForEach(content.files) { row($0, keep: false) }
        }
    }

    private func row(_ file: FileInfo, keep: Bool) -> some View {
        let selected = store.selection.contains(file.id)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 12) {
            if keep {
                Text("Keep").font(.system(size: 11, weight: .bold)).padding(.horizontal, 7).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.2))
            } else {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(Theme.ink)
            }
            Text(file.name).font(.system(size: 15, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 8)
            if !file.isLocal {
                Text("Not downloaded").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Text(formatted(file.bytes)).font(.system(size: 14)).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(shape.fill(.white))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 1.5))
        .contentShape(shape)
        .onTapGesture { if !keep { store.toggle(file.id) } }
    }
}
