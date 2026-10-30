import NeuralyzerKit
import SwiftUI

struct CleanSheet: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let items: [Item]

    @State private var working = false
    @State private var report: CleanReport?

    var body: some View {
        VStack(spacing: 22) {
            if let report {
                finished(report)
            } else {
                confirm
            }
        }
        .padding(36)
        .frame(width: 400)
    }

    private var confirm: some View {
        let bytes = items.reduce(Int64(0)) { $0 + $1.bytes }
        let blockers = store.blockers(for: items)
        return VStack(spacing: 22) {
            Text("Clean \(formatBytes(bytes))?").font(.system(size: 24, weight: .bold))
            if items.contains(where: { $0.action == .trash }) {
                Text("Some items go to the Trash.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            if !blockers.isEmpty {
                Text("Quit \(blockers.joined(separator: " and ")) first.").font(.system(size: 14)).foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button {
                    working = true
                    Task {
                        let result = await store.clean(items)
                        working = false
                        if result.trashed > 0 || !result.failures.isEmpty { report = result } else { finish() }
                    }
                } label: {
                    if working { ProgressView().controlSize(.small).frame(width: 44) } else { Text("Clean") }
                }
                .buttonStyle(PillButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(working || !blockers.isEmpty)
            }
        }
    }

    private func finished(_ report: CleanReport) -> some View {
        VStack(spacing: 22) {
            Text(report.failures.isEmpty ? "Done" : "Could not clean \(report.failures.count)")
                .font(.system(size: 24, weight: .bold))
            if report.trashed > 0 {
                Text("\(formatBytes(report.trashed)) is in the Trash.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Done") { finish() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                if report.trashed > 0 {
                    Button {
                        working = true
                        Task {
                            await store.emptyTrash()
                            finish()
                        }
                    } label: {
                        if working { ProgressView().controlSize(.small).frame(width: 80) } else { Text("Empty Trash") }
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(working)
                }
            }
        }
    }

    private func finish() {
        dismiss()
        store.scan()
    }
}
