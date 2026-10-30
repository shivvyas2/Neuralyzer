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
                        ProgressView(value: store.progress).tint(Theme.ink)
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
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { if store.results.isEmpty && !store.scanning { store.scan() } }
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
