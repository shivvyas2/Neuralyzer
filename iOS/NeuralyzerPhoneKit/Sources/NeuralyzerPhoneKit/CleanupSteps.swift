import Foundation

/// A step only the person can take, because iOS keeps every other app's data out of reach.
public struct CleanupStep: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    /// An app Neuralyzer may open for this step. Only public URL schemes, never Settings deep links.
    public let openURL: URL?
    public let openLabel: String?
}

/// Ordered by how much space each step usually frees.
public let cleanupSteps: [CleanupStep] = [
    CleanupStep(id: "whatsapp-manage", title: "Clear WhatsApp's big files",
                detail: "In WhatsApp, open Settings, Storage and Data, Manage Storage. Sort by size and delete large videos and forwarded files.",
                openURL: URL(string: "whatsapp://"), openLabel: "Open WhatsApp"),
    CleanupStep(id: "whatsapp-stop", title: "Stop WhatsApp filling your phone",
                detail: "In WhatsApp, open Settings, Chats and turn off Save to Photos. Then Storage and Data, Media Auto-Download: set each to Wi-Fi or Never.",
                openURL: URL(string: "whatsapp://"), openLabel: "Open WhatsApp"),
    CleanupStep(id: "reinstall", title: "Reinstall heavy apps to wipe their caches",
                detail: "In Settings, General, iPhone Storage, look at Documents & Data for apps like Instagram, TikTok, Snapchat, and Chrome. Delete the biggest and download them again. For WhatsApp, back up chats first in WhatsApp, Settings, Chats, Chat Backup.",
                openURL: nil, openLabel: nil),
    CleanupStep(id: "messages", title: "Keep messages for one year",
                detail: "In Settings, Apps, Messages, set Keep Messages to 1 Year. In Settings, General, iPhone Storage, Messages, review large attachments.",
                openURL: nil, openLabel: nil),
    CleanupStep(id: "downloads", title: "Remove offline downloads",
                detail: "Delete downloaded maps in Google Maps, and downloads in Netflix, Spotify, Podcasts, and Music you no longer need.",
                openURL: nil, openLabel: nil),
    CleanupStep(id: "safari", title: "Clear Safari website data",
                detail: "In Settings, Apps, Safari, tap Clear History and Website Data.",
                openURL: nil, openLabel: nil),
    CleanupStep(id: "restart", title: "Restart your iPhone",
                detail: "After the steps above, restart. iOS clears much of System Data once caches are gone.",
                openURL: nil, openLabel: nil),
]

/// Space freed since the checklist was opened. Never negative.
public func freedSince(baseline: Int64, nowFree: Int64) -> Int64 {
    max(0, nowFree - baseline)
}
