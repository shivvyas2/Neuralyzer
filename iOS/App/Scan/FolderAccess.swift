import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The iCloud Drive folder the person granted, kept as a security scoped bookmark so it is asked once.
enum FolderAccess {
    private static let key = "icloudFolderBookmark"

    static func save(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static var hasFolder: Bool { UserDefaults.standard.data(forKey: key) != nil }

    /// Runs `body` with access to the saved folder, or returns nil when there is none.
    static func withFolder<T>(_ body: (URL) -> T) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        if stale { save(url) }
        return body(url)
    }
}

/// Apple's folder picker, opened on iCloud Drive.
struct FolderPicker: UIViewControllerRepresentable {
    let picked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(picked: picked) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let picked: (URL) -> Void
        init(picked: @escaping (URL) -> Void) { self.picked = picked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { picked(url) }
        }
    }
}
