import SwiftUI

/// What iOS keeps out of reach of every app, with the only numbers iOS shares.
struct OnlyYouCard: View {
    @Environment(PhoneStore.self) private var store

    var body: some View {
        let disk = store.disk
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            Text("Only you can do these").font(Theme.title(22))
            Text("\(formatted(disk.free)) free of \(formatted(disk.total))").font(.system(size: 14, weight: .medium))
            if store.freedThisSession > 0 {
                Text("\(formatted(store.freedThisSession)) deleted with Neuralyzer").font(.system(size: 14, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 10) {
                step("WhatsApp: Settings, Storage and Data, Manage Storage.")
                step("Settings, General, iPhone Storage: offload apps you do not use.")
                step("Photos, Albums, Recently Deleted: delete all to free space now.")
            }
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(.white))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
    }

    private func step(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Theme.ink).frame(width: 5, height: 5)
            Text(text)
        }
    }
}
