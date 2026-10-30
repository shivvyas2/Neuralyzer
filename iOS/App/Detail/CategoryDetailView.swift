import NeuralyzerPhoneKit
import Photos
import SwiftUI

struct CategoryDetailView: View {
    @Environment(PhoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let category: PhoneCategory
    @State private var confirmFiles = false
    @State private var confirmContacts = false

    var body: some View {
        let content = store.results[category] ?? CategoryContent()
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(category.title).font(Theme.title(34))
                    if !content.photoGroups.isEmpty || !content.photos.isEmpty {
                        PhotoGridView(content: content)
                    } else if !content.fileGroups.isEmpty || !content.files.isEmpty {
                        FileListView(content: content)
                    } else {
                        ContactListView(groups: content.contactGroups)
                    }
                }
                .padding(20)
            }
            actionBar(content)
        }
        .onChange(of: content.isEmpty) { _, empty in if empty { dismiss() } }
        .confirmationDialog("Move \(selectedFiles(content)) files to the Trash?", isPresented: $confirmFiles, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { _ = store.trashFiles(in: category) }
        }
        .confirmationDialog("Merge \(selectedGroups(content)) contacts?", isPresented: $confirmContacts, titleVisibility: .visible) {
            Button("Merge") { _ = store.mergeContacts() }
        } message: {
            Text("A backup is saved in Files, in the Neuralyzer folder.")
        }
    }

    @ViewBuilder
    private func actionBar(_ content: CategoryContent) -> some View {
        Group {
            if category == .contacts {
                Button("Merge \(selectedGroups(content))") { confirmContacts = true }
                    .disabled(selectedGroups(content) == 0)
            } else if category == .icloudDuplicates || category == .icloudLarge {
                Button("Delete \(formatted(selectedBytes(content)))") { confirmFiles = true }
                    .disabled(selectedFiles(content) == 0)
            } else {
                Button("Delete \(aboutSize(selectedBytes(content)))") { Task { _ = await store.deletePhotos(in: category) } }
                    .disabled(selectedBytes(content) == 0)
            }
        }
        .buttonStyle(InkButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func selectedBytes(_ c: CategoryContent) -> Int64 {
        (c.photos + c.photoGroups.flatMap(\.others)).filter { store.selection.contains($0.id) }.reduce(0) { $0 + estimatedBytes($1) }
            + (c.files + c.fileGroups.flatMap(\.others)).filter { store.selection.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    private func selectedFiles(_ c: CategoryContent) -> Int {
        (c.files + c.fileGroups.flatMap(\.others)).filter { store.selection.contains($0.id) }.count
    }

    private func selectedGroups(_ c: CategoryContent) -> Int {
        c.contactGroups.filter { store.selection.contains($0.keep.id) }.count
    }
}
