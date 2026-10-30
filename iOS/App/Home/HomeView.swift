import NeuralyzerPhoneKit
import SwiftUI

struct HomeView: View {
    @Environment(PhoneStore.self) private var store
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if store.scanning {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: store.progress).tint(Theme.ink)
                            Text(store.progress < 0.55 ? "Reading your photos" : store.progress < 0.7 ? "Checking iCloud Drive and contacts" : "Looking for similar photos")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    accessNotice
                    if !store.recommended.isEmpty {
                        RecommendedCard()
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.categories, id: \.self) { category in
                            NavigationLink(value: category) { CategoryCard(category: category) }
                                .buttonStyle(.plain)
                        }
                    }
                    if !store.scanning && !store.results.isEmpty {
                        OnlyYouCard()
                    }
                }
                .padding(20)
            }
            .navigationDestination(for: PhoneCategory.self) { CategoryDetailView(category: $0) }
            .navigationDestination(for: Route.self) { _ in RecommendedView() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { if store.results.isEmpty && !store.scanning { store.scan() } }
    }

    @ViewBuilder
    private var accessNotice: some View {
        switch store.photosAccess {
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 10) {
                Text("Neuralyzer needs Photos access to find duplicates.").font(.system(size: 15, weight: .medium))
                Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                    .buttonStyle(InkButtonStyle())
            }
        case .limited:
            Text("Neuralyzer can see only the photos you chose.").font(.system(size: 14)).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private var header: some View {
        let disk = store.disk
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Neuralyzer").font(Theme.title(36))
                Text("\(formatted(disk.total - disk.free)) used of \(formatted(disk.total))")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Scan") { store.scan() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.ink))
                .disabled(store.scanning)
                .opacity(store.scanning ? 0.4 : 1)
        }
        .padding(.top, 8)
    }
}

func formatted(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
