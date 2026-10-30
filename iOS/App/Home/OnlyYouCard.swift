import NeuralyzerPhoneKit
import SwiftUI

/// The way in to the steps only the person can take, with how many are done.
struct OnlyYouCard: View {
    @Environment(PhoneStore.self) private var store
    @AppStorage("cleanDone") private var done = ""

    var body: some View {
        let disk = store.disk
        let finished = Set(done.split(separator: ",").map(String.init)).intersection(cleanupSteps.map(\.id)).count
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        NavigationLink(value: Route.cleanOtherApps) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clean other apps").font(Theme.title(22)).foregroundStyle(Theme.ink)
                Text("WhatsApp, app caches, and System Data").font(.system(size: 14)).foregroundStyle(.secondary)
                HStack {
                    Text("\(formatted(disk.free)) free").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("\(finished) of \(cleanupSteps.count) done").font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(.white))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// Steps for what iOS keeps out of reach of every app, biggest first, with the space freed so far.
struct CleanOtherAppsView: View {
    @Environment(PhoneStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("cleanDone") private var done = ""
    @AppStorage("cleanBaseline") private var baseline: Double = 0
    @State private var free: Int64 = 0

    private var doneIDs: Set<String> { Set(done.split(separator: ",").map(String.init)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Clean other apps").font(Theme.title(34))
                Text("iOS lets no app reach another app's data, so these steps are yours. Neuralyzer shows how much each one frees.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    stat(formatted(free), "free now")
                    stat(formatted(freedSince(baseline: Int64(baseline), nowFree: free)), "freed since you started")
                }
                ForEach(cleanupSteps) { step in row(step) }
                Button("Start over") {
                    done = ""
                    baseline = Double(store.disk.free)
                    free = store.disk.free
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(20)
        }
        .onAppear {
            free = store.disk.free
            if baseline == 0 { baseline = Double(free) }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { free = store.disk.free } }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.title(22)).foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Theme.yellow))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 1.5))
    }

    private func row(_ step: CleanupStep) -> some View {
        let isDone = doneIDs.contains(step.id)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(alignment: .top, spacing: 12) {
            Button { toggle(step.id) } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(isDone ? "Done" : "Not done")
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title).font(.system(size: 16, weight: .semibold)).strikethrough(isDone, color: Theme.ink.opacity(0.4))
                Text(step.detail).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let url = step.openURL, let label = step.openLabel {
                    Button(label) { openURL(url) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(shape.fill(.white))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 1.5))
    }

    private func toggle(_ id: String) {
        var ids = doneIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        done = ids.sorted().joined(separator: ",")
    }
}
