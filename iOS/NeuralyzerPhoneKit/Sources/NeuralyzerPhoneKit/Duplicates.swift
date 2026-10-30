import Foundation

/// A set of copies: one to keep, the rest to delete.
public struct PhotoGroup: Sendable, Hashable {
    public let keep: PhotoInfo
    public let others: [PhotoInfo]
    /// Exact copies are preselected; near identical shots are not.
    public let exact: Bool

    public init(keep: PhotoInfo, others: [PhotoInfo], exact: Bool) {
        self.keep = keep
        self.others = others
        self.exact = exact
    }
}

public func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }

/// Copies with the same pixel size and nearly the same thumbnail, whatever their dates.
/// Re-saved WhatsApp photos and re-imports carry new dates, so dates are ignored.
/// A small thumbnail hash also matches posed shots taken seconds apart, so every pair must pass
/// `confirm` (the app checks a near zero Vision distance) before it counts as an exact copy.
/// Burst frames are left to the Bursts card, which knows the representative and your picks.
public func exactDuplicateGroups(_ photos: [PhotoInfo], maxHamming: Int = 2,
                                 confirm: (PhotoInfo, PhotoInfo) -> Bool = { _, _ in true }) -> [PhotoGroup] {
    let hashed = photos.filter { $0.thumbHash != nil && $0.burstID == nil }
    let buckets = Dictionary(grouping: hashed) { "\($0.isVideo)-\($0.pixelWidth)x\($0.pixelHeight)" }
    return buckets.values.flatMap { bucket in
        groups(of: bucket, exact: true) { a, b in
            hammingDistance(a.thumbHash!, b.thumbHash!) <= maxHamming && (!a.isVideo || abs(a.duration - b.duration) <= 0.5)
                && confirm(a, b)
        }
    }
}

/// Near identical photos by visual distance, compared within buckets of similar shape.
/// The costly `distance` only runs on pairs whose thumbnail hashes are already close, never more than
/// `maxComparisons` times, and not after `deadline`, so a huge library cannot stall the scan.
/// `progress` moves photo by photo from 0 to 1.
public func nearDuplicateGroups(
    _ photos: [PhotoInfo], excluding: Set<String>, distance: (PhotoInfo, PhotoInfo) -> Float?, threshold: Float,
    prefilterHamming: Int = 14, maxComparisons: Int = 20_000, deadline: Date? = nil, progress: (Double) -> Void = { _ in }
) -> [PhotoGroup] {
    let candidates = photos.filter { !$0.isVideo && !excluding.contains($0.id) && $0.pixelHeight > 0 && $0.thumbHash != nil && $0.burstID == nil }
    let buckets = Array(Dictionary(grouping: candidates) { Int((Double($0.pixelWidth) / Double($0.pixelHeight) * 20).rounded()) }.values)
    let total = max(candidates.count, 1)
    var done = 0
    var budget = maxComparisons
    var out: [PhotoGroup] = []
    bucketLoop: for bucket in buckets {
        var parent = Array(bucket.indices)
        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        for i in bucket.indices {
            if budget <= 0 || (deadline.map { Date() > $0 } ?? false) { break bucketLoop }
            for j in bucket.indices where j > i && budget > 0 {
                guard hammingDistance(bucket[i].thumbHash!, bucket[j].thumbHash!) <= prefilterHamming else { continue }
                budget -= 1
                if (distance(bucket[i], bucket[j]) ?? .infinity) < threshold { parent[root(j)] = root(i) }
            }
            done += 1
            if done % max(1, total / 100) == 0 { progress(Double(done) / Double(total)) }
        }
        let roots = bucket.indices.map(root)
        out += collect(bucket, roots: roots)
    }
    progress(1)
    return out
}

private func collect(_ bucket: [PhotoInfo], roots: [Int]) -> [PhotoGroup] {
    Dictionary(grouping: bucket.indices) { roots[$0] }.values.filter { $0.count > 1 }.map { indices in
        let members = indices.map { bucket[$0] }
        let keep = pickKeeper(members)
        return PhotoGroup(keep: keep, others: members.filter { $0.id != keep.id }, exact: false)
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

/// Groups after `ids` were deleted. A group whose kept copy is gone is dropped entirely, so its other
/// copies are never deleted from here with nothing left behind.
public func removing(_ ids: Set<String>, from groups: [PhotoGroup]) -> [PhotoGroup] {
    groups.compactMap { g in
        guard !ids.contains(g.keep.id) else { return nil }
        let others = g.others.filter { !ids.contains($0.id) }
        return others.isEmpty ? nil : PhotoGroup(keep: g.keep, others: others, exact: g.exact)
    }
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
