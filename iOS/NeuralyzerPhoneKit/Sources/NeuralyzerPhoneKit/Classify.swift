import Foundation

/// Sorts photos into the single kind categories. Duplicates are grouped separately.
public func classify(_ photos: [PhotoInfo], blurThreshold: Double = 60, bigVideoBytes: Int64 = 200_000_000) -> [PhoneCategory: [PhotoInfo]] {
    var out: [PhoneCategory: [PhotoInfo]] = [:]
    for p in photos {
        if p.isScreenshot { out[.screenshots, default: []].append(p) }
        if p.isVideo, p.originalFilename?.hasPrefix("RPReplay") == true { out[.screenRecordings, default: []].append(p) }
        if p.burstID != nil, !p.isBurstRepresentative, !p.isBurstUserPick { out[.bursts, default: []].append(p) }
        if !p.isVideo, !p.isScreenshot, let score = p.blurScore, score < blurThreshold { out[.blurry, default: []].append(p) }
        if p.isVideo, estimatedBytes(p) > bigVideoBytes { out[.bigVideos, default: []].append(p) }
        if p.inWhatsAppAlbum { out[.whatsapp, default: []].append(p) }
    }
    return out
}

/// Burst extras are the only photo kind checked by default; everything else waits for the person.
public func isPreselected(_ category: PhoneCategory) -> Bool {
    category == .bursts
}
