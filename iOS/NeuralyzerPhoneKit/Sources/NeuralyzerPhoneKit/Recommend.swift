import Foundation

/// One group of things that are safe to delete, with the reason in plain words.
public struct Recommendation: Sendable, Hashable, Identifiable {
    public let reason: String
    public let ids: [String]
    public let bytes: Int64
    public var id: String { reason }

    public init(reason: String, ids: [String], bytes: Int64) {
        self.reason = reason
        self.ids = ids
        self.bytes = bytes
    }
}

/// What Neuralyzer suggests deleting. Favorites and near identical shots are never suggested, and each
/// item appears under one reason only. Largest first.
public func recommendations(photos: [PhotoInfo], photoGroups: [PhotoGroup], fileGroups: [FileGroup], now: Date,
                            blurThreshold: Double = 60) -> [Recommendation] {
    let month = now.addingTimeInterval(-30 * 86400)
    let quarter = now.addingTimeInterval(-90 * 86400)
    func olderThan(_ p: PhotoInfo, _ cutoff: Date) -> Bool { (p.created ?? .distantFuture) < cutoff }

    let rules: [(String, [PhotoInfo])] = [
        ("Extra copies of photos you already have", photoGroups.filter(\.exact).flatMap(\.others)),
        ("Extra shots from bursts", photos.filter { $0.burstID != nil && !$0.isBurstRepresentative && !$0.isBurstUserPick }),
        ("Screenshots older than 30 days", photos.filter { $0.isScreenshot && olderThan($0, month) }),
        ("Screen recordings older than 30 days", photos.filter { $0.isVideo && $0.originalFilename?.hasPrefix("RPReplay") == true && olderThan($0, month) }),
        ("WhatsApp media older than 90 days", photos.filter { $0.inWhatsAppAlbum && olderThan($0, quarter) }),
        ("Blurry photos", photos.filter { !$0.isVideo && !$0.isScreenshot && ($0.blurScore ?? .infinity) < blurThreshold }),
    ]

    var taken = Set<String>()
    var out: [Recommendation] = []
    for (reason, candidates) in rules {
        var seen = Set<String>()
        let items = candidates.filter { !$0.isFavorite && !taken.contains($0.id) && seen.insert($0.id).inserted }
        guard !items.isEmpty else { continue }
        taken.formUnion(items.map(\.id))
        out.append(Recommendation(reason: reason, ids: items.map(\.id), bytes: items.reduce(0) { $0 + estimatedBytes($1) }))
    }
    let files = fileGroups.filter(\.verified).flatMap(\.others)
    if !files.isEmpty {
        out.append(Recommendation(reason: "Extra copies of iCloud files", ids: files.map(\.id), bytes: files.reduce(0) { $0 + $1.bytes }))
    }
    return out.sorted { $0.bytes > $1.bytes }
}
