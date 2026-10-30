import Foundation

public enum CategoryID: String, CaseIterable, Sendable, Hashable {
    case xcode, simulators, claudeCode, packageCaches, projectBuilds, vms, appCaches, junk, trash, largeFiles, oldFiles

    public var title: String {
        switch self {
        case .xcode: "Xcode"
        case .simulators: "Simulators"
        case .claudeCode: "Claude Code"
        case .packageCaches: "Package Caches"
        case .projectBuilds: "Build Folders"
        case .vms: "VMs"
        case .appCaches: "App Caches"
        case .junk: "Junk"
        case .trash: "Trash"
        case .largeFiles: "Large Files"
        case .oldFiles: "Old Files"
        }
    }

    public var symbol: String {
        switch self {
        case .xcode: "hammer"
        case .simulators: "iphone"
        case .claudeCode: "sparkle"
        case .packageCaches: "shippingbox"
        case .projectBuilds: "folder.badge.gearshape"
        case .vms: "server.rack"
        case .appCaches: "square.stack.3d.up"
        case .junk: "xmark.bin"
        case .trash: "trash"
        case .largeFiles: "externaldrive"
        case .oldFiles: "clock.arrow.circlepath"
        }
    }
}

public enum Action: Sendable, Hashable {
    /// Remove permanently.
    case delete
    /// Move to the user's Trash.
    case trash
    case simctlDeleteDevice(udid: String)
    case simctlDeleteRuntime(id: String)
    /// Remove the session logs inside a folder, never the names in `keep`.
    case deleteContents(keep: Set<String>)
}

public struct Item: Identifiable, Sendable, Hashable {
    public let id: String
    public let category: CategoryID
    public let name: String
    public let url: URL
    /// The category root the safety guard checks against. Nil only for simctl rows.
    public let root: URL?
    public let bytes: Int64
    public let action: Action
    public let preselected: Bool

    public init(id: String, category: CategoryID, name: String, url: URL, root: URL?, bytes: Int64, action: Action, preselected: Bool) {
        self.id = id
        self.category = category
        self.name = name
        self.url = url
        self.root = root
        self.bytes = bytes
        self.action = action
        self.preselected = preselected
    }
}

public struct CategoryResult: Sendable {
    public let id: CategoryID
    public let items: [Item]
    public let bytes: Int64

    public init(id: CategoryID, items: [Item]) {
        self.id = id
        self.items = items.sorted { $0.bytes > $1.bytes }
        self.bytes = items.reduce(0) { $0 + $1.bytes }
    }
}
