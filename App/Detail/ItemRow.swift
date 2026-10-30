import AppKit
import NeuralyzerKit
import SwiftUI

struct ItemRow: View {
    let item: Item
    let selected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(selected ? Color.primary : Color.secondary.opacity(0.5))
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.05)))
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 16)
                Text(formatBytes(item.bytes))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .surface()
        .contextMenu {
            if item.root != nil {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            }
        }
    }

    private var symbol: String {
        switch item.action {
        case .simctlDeleteDevice: "iphone"
        case .simctlDeleteRuntime: "cpu"
        default:
            item.url.hasDirectoryPath || (try? item.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                ? "folder" : "doc"
        }
    }
}
