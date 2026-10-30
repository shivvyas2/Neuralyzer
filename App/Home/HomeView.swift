import NeuralyzerKit
import SwiftUI

struct HomeView: View {
    @Environment(ScanStore.self) private var store
    @State private var path: [HomeRoute] = []

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 20)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    if !store.scanning && !store.recommended.isEmpty {
                        Button { path.append(.recommended) } label: { RecommendedCard() }
                            .buttonStyle(.plain)
                    }
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(store.categories, id: \.id) { result in
                            Button { path.append(.category(result.id)) } label: { CategoryCard(result: result) }
                                .buttonStyle(.plain)
                        }
                    }
                    .animation(.smooth, value: store.categories.map(\.id))
                }
                .padding(.horizontal, 44)
                .padding(.top, 36)
                .padding(.bottom, 44)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .category(let id): CategoryDetailView(category: id)
                case .recommended: RecommendedView()
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
        }
        .onAppear { if store.results.isEmpty && !store.scanning { store.scan() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Neuralyzer").font(Theme.title(40))
                Text("\(formatBytes(store.used)) used of \(formatBytes(store.total))")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button { store.scan() } label: {
                if store.scanning {
                    ProgressView().controlSize(.small).frame(width: 38)
                } else {
                    Text("Scan")
                }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(store.scanning)
        }
    }
}

enum HomeRoute: Hashable {
    case category(CategoryID)
    case recommended
}
