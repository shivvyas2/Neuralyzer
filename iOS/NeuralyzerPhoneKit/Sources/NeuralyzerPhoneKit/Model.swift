import Foundation

public enum PhoneCategory: String, CaseIterable, Sendable, Hashable {
    case duplicates, screenshots, screenRecordings, bursts, blurry, bigVideos, whatsapp, icloudDuplicates, icloudLarge, contacts

    public var title: String {
        switch self {
        case .duplicates: "Duplicates"
        case .screenshots: "Screenshots"
        case .screenRecordings: "Screen Recordings"
        case .bursts: "Bursts"
        case .blurry: "Blurry"
        case .bigVideos: "Big Videos"
        case .whatsapp: "WhatsApp"
        case .icloudDuplicates: "iCloud Duplicates"
        case .icloudLarge: "iCloud Large & Old"
        case .contacts: "Contacts"
        }
    }

    public var symbol: String {
        switch self {
        case .duplicates: "square.on.square"
        case .screenshots: "camera.viewfinder"
        case .screenRecordings: "record.circle"
        case .bursts: "square.stack.3d.down.right"
        case .blurry: "camera.filters"
        case .bigVideos: "film"
        case .whatsapp: "message"
        case .icloudDuplicates: "doc.on.doc"
        case .icloudLarge: "icloud"
        case .contacts: "person.2"
        }
    }
}

/// What the kit needs to know about one photo or video. The app fills it in from PhotoKit.
public struct PhotoInfo: Sendable, Hashable, Identifiable {
    public let id: String
    public let isVideo: Bool
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let duration: Double
    public let created: Date?
    public let isFavorite: Bool
    public let hasEdits: Bool
    public let isScreenshot: Bool
    public let originalFilename: String?
    public let burstID: String?
    public let isBurstRepresentative: Bool
    public let isBurstUserPick: Bool
    public let inWhatsAppAlbum: Bool
    /// 64 bit difference hash of a small local thumbnail. Nil when no thumbnail is on the phone.
    public let thumbHash: UInt64?
    /// Laplacian variance of a small thumbnail. Lower is blurrier.
    public let blurScore: Double?

    public init(id: String, isVideo: Bool, pixelWidth: Int, pixelHeight: Int, duration: Double, created: Date?,
                isFavorite: Bool, hasEdits: Bool, isScreenshot: Bool, originalFilename: String?, burstID: String?,
                isBurstRepresentative: Bool, isBurstUserPick: Bool, inWhatsAppAlbum: Bool, thumbHash: UInt64?, blurScore: Double?) {
        self.id = id
        self.isVideo = isVideo
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.created = created
        self.isFavorite = isFavorite
        self.hasEdits = hasEdits
        self.isScreenshot = isScreenshot
        self.originalFilename = originalFilename
        self.burstID = burstID
        self.isBurstRepresentative = isBurstRepresentative
        self.isBurstUserPick = isBurstUserPick
        self.inWhatsAppAlbum = inWhatsAppAlbum
        self.thumbHash = thumbHash
        self.blurScore = blurScore
    }

    public var pixels: Int { pixelWidth * pixelHeight }
}
