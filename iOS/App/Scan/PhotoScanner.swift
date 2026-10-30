import CoreGraphics
import NeuralyzerPhoneKit
import Photos
import UIKit
import Vision

/// Reads the Photos library into `PhotoInfo` values. Only thumbnails already on the phone are used;
/// nothing is ever downloaded from iCloud.
final class PhotoScanner: @unchecked Sendable {
    private let manager = PHImageManager.default()
    private var printCache: [String: VNFeaturePrintObservation] = [:]
    private let lock = NSLock()

    func scan(progress: @escaping @Sendable (Double) -> Void) -> [PhotoInfo] {
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: options)
        let whatsapp = whatsAppIDs()
        var out: [PhotoInfo] = []
        out.reserveCapacity(assets.count)
        let total = max(assets.count, 1)
        assets.enumerateObjects { asset, index, _ in
            // Thumbnails are autoreleased; drain them per photo so big libraries do not run out of memory.
            autoreleasepool { out.append(self.info(for: asset, whatsapp: whatsapp)) }
            if index % 50 == 0 { progress(Double(index) / Double(total)) }
        }
        progress(1)
        return out
    }

    private func info(for asset: PHAsset, whatsapp: Set<String>) -> PhotoInfo {
        let isVideo = asset.mediaType == .video
        var filename: String?
        if isVideo { filename = PHAssetResource.assetResources(for: asset).first?.originalFilename }
        var hash: UInt64?
        var blur: Double?
        if let image = thumbnail(asset, side: 64) {
            if let tiny = grayscale(image, width: 9, height: 8) { hash = differenceHash(gray: tiny, width: 9, height: 8) }
            if !isVideo, let small = grayscale(image, width: 64, height: 64) { blur = laplacianVariance(gray: small, width: 64, height: 64) }
        }
        return PhotoInfo(
            id: asset.localIdentifier, isVideo: isVideo, pixelWidth: asset.pixelWidth, pixelHeight: asset.pixelHeight,
            duration: asset.duration, created: asset.creationDate, isFavorite: asset.isFavorite,
            // modificationDate also changes on favoriting and syncing, so it says nothing about edits.
            hasEdits: false,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot), originalFilename: filename,
            burstID: asset.burstIdentifier, isBurstRepresentative: asset.representsBurst,
            isBurstUserPick: asset.burstSelectionTypes.contains(.userPick), inWhatsAppAlbum: whatsapp.contains(asset.localIdentifier),
            thumbHash: hash, blurScore: blur)
    }

    private func whatsAppIDs() -> Set<String> {
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var ids = Set<String>()
        albums.enumerateObjects { album, _, _ in
            guard album.localizedTitle == "WhatsApp" else { return }
            PHAsset.fetchAssets(in: album, options: nil).enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        }
        return ids
    }

    /// A local thumbnail, or nil when only iCloud has the photo.
    func thumbnail(_ asset: PHAsset, side: CGFloat) -> CGImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        var result: CGImage?
        manager.requestImage(for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: options) { image, _ in
            result = image?.cgImage
        }
        return result
    }

    private func grayscale(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? pixels : nil
    }

    /// Visual distance between two photos from Vision feature prints, computed on demand and cached.
    func distance(_ a: PhotoInfo, _ b: PhotoInfo) -> Float? {
        guard let pa = featurePrint(a.id), let pb = featurePrint(b.id) else { return nil }
        var d: Float = 0
        do { try pa.computeDistance(&d, to: pb) } catch { return nil }
        return d
    }

    private func featurePrint(_ id: String) -> VNFeaturePrintObservation? {
        if let cached = lock.withLock({ printCache[id] }) { return cached }
        let print: VNFeaturePrintObservation? = autoreleasepool {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                  let image = thumbnail(asset, side: 256) else { return nil }
            let request = VNGenerateImageFeaturePrintRequest()
            try? VNImageRequestHandler(cgImage: image).perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        }
        guard let print else { return nil }
        lock.withLock { printCache[id] = print }
        return print
    }
}
