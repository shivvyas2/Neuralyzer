import SwiftUI

/// One screen per permission. Contacts and iCloud Drive can be skipped.
struct OnboardingView: View {
    @Environment(PhoneStore.self) private var store
    @Binding var onboarded: Bool
    @State private var step = 0
    @State private var picking = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            switch step {
            case 0:
                AppMark(size: 120)
                Text("Neuralyzer").font(Theme.title(44))
                Spacer()
                Button("Continue") { advance() }.buttonStyle(InkButtonStyle())
            case 1:
                badge("photo.on.rectangle", Theme.yellow)
                Text("Photos").font(Theme.title(40))
                Text("Find duplicates, screenshots, and big videos.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                Spacer()
                Button("Allow Photos") { Task { await store.requestPhotos(); advance() } }.buttonStyle(InkButtonStyle())
            case 2:
                badge("person.2", Theme.coral)
                Text("Contacts").font(Theme.title(40))
                Text("Find and merge duplicate contacts.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                Spacer()
                Button("Allow Contacts") { Task { await store.requestContacts(); advance() } }.buttonStyle(InkButtonStyle())
                Button("Skip") { advance() }.buttonStyle(QuietButtonStyle())
            case 3:
                badge("icloud", Theme.blue)
                Text("iCloud Drive").font(Theme.title(40))
                Text("Choose your iCloud Drive folder to find duplicate and large files.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                Spacer()
                Button("Choose iCloud Drive") { picking = true }.buttonStyle(InkButtonStyle())
                Button("Skip") { advance() }.buttonStyle(QuietButtonStyle())
            default:
                badge("checkmark", Theme.green)
                Text("All set").font(Theme.title(44))
                Spacer()
                Button("Start Scan") {
                    onboarded = true
                    store.scan()
                }
                .buttonStyle(InkButtonStyle())
            }
        }
        .font(.system(size: 17))
        .padding(28)
        .animation(.smooth, value: step)
        .sheet(isPresented: $picking) {
            FolderPicker { url in
                store.folderPicked(url)
                picking = false
                advance()
            }
            .ignoresSafeArea()
        }
    }

    private func advance() { step += 1 }

    private func badge(_ symbol: String, _ color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Image(systemName: symbol)
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 96, height: 96)
            .background(shape.fill(color))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
    }
}
