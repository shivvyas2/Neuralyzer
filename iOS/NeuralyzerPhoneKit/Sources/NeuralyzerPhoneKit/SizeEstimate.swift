import Foundation

/// A size estimate from public metadata only, since PhotoKit has no public file size.
/// Photos: about 0.45 bytes per pixel (HEIC). Videos: duration times a bitrate for the resolution.
public func estimatedBytes(_ p: PhotoInfo) -> Int64 {
    guard p.isVideo else { return Int64(Double(p.pixels) * 0.45) }
    let width = max(p.pixelWidth, p.pixelHeight)
    let bytesPerSecond: Double = width >= 3840 ? 6_000_000 : width >= 1920 ? 2_200_000 : 1_000_000
    return Int64(p.duration * bytesPerSecond)
}

public func aboutSize(_ bytes: Int64) -> String {
    "About " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
