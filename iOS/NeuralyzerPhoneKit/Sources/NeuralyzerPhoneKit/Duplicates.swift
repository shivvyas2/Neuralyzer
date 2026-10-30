import Foundation

/// A set of copies: one to keep, the rest to delete.
public struct PhotoGroup: Sendable, Hashable {
    public let keep: PhotoInfo
    public let others: [PhotoInfo]
    /// Exact copies are preselected; near identical shots are not.
    public let exact: Bool
}

public func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }

/// Copies with the same pixel size and nearly the same thumbnail, whatever their dates.
/// Re-saved WhatsApp photos and re-imports carry new dates, so dates are ignored.
public func exactDuplicateGroups(_ photos: [PhotoInfo], maxHamming: Int = 2) -> [PhotoGroup] {
    let hashed = photos.filter { $0.thumbHash != nil }
    let buckets = Dictionary(grouping: hashed) { "\($0.isVideo)-\($0.pixelWidth)x\($0.pixelHeight)" }
    return buckets.values.flatMap { bucket in
        groups(of: bucket, exact: true) { a, b in
            hammingDistance(a.thumbHash!, b.thumbHash!) <= maxHamming && (!a.isVideo || abs(a.duration - b.duration) <= 0.5)
        }
    }
}

/// Near identical photos by visual distance, compared within buckets of similar shape.
/// The costly `distance` only runs on pairs whose thumbnail hashes are already close,
/// which keeps a large library to a few thousand comparisons.
public func nearDuplicateGroups(
    _ photos: [PhotoInfo], excluding: Set<String>, distance: (PhotoInfo, PhotoInfo) -> Float?, threshold: Float,
    prefilterHamming: Int = 14
) -> [PhotoGroup] {
    let candidates = photos.filter { !$0.isVideo && !excluding.contains($0.id) && $0.pixelHeight > 0 && $0.thumbHash != nil }
    let buckets = Dictionary(grouping: candidates) { Int((Double($0.pixelWidth) / Double($0.pixelHeight) * 20).rounded()) }
    return buckets.values.flatMap { bucket in
        groups(of: bucket, exact: false) { a, b in
            hammingDistance(a.thumbHash!, b.thumbHash!) <= prefilterHamming && (distance(a, b) ?? .infinity) < threshold
        }
    }
}

/// The copy to keep: a favorite, then an edited one, then the most pixels, then the earliest.
public func pickKeeper(_ group: [PhotoInfo]) -> PhotoInfo {
    group.min { a, b in
        if a.isFavorite != b.isFavorite { return a.isFavorite }
        if a.hasEdits != b.hasEdits { return a.hasEdits }
        if a.pixels != b.pixels { return a.pixels > b.pixels }
        switch (a.created, b.created) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.id < b.id
        }
    }!
}

/// Connected groups under `linked`, by union find.
private func groups(of items: [PhotoInfo], exact: Bool, linked: (PhotoInfo, PhotoInfo) -> Bool) -> [PhotoGroup] {
    guard items.count > 1 else { return [] }
    var parent = Array(items.indices)
    func root(_ i: Int) -> Int {
        var i = i
        while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
        return i
    }
    for i in items.indices {
        for j in items.indices where j > i && linked(items[i], items[j]) {
            parent[root(j)] = root(i)
        }
    }
    let sets = Dictionary(grouping: items.indices, by: root).values.filter { $0.count > 1 }
    return sets.map { indices in
        let members = indices.map { items[$0] }
        let keep = pickKeeper(members)
        return PhotoGroup(keep: keep, others: members.filter { $0.id != keep.id }, exact: exact)
    }
}
