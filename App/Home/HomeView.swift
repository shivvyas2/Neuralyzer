import NeuralyzerKit
import SwiftUI

struct HomeView: View {
    @Environment(ScanStore.self) private var store
    @State private var path: [CategoryID] = []

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 20)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(store.categories, id: \.id) { result in
                            Button { path.append(result.id) } label: { CategoryCard(result: result) }
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
            .navigationDestination(for: CategoryID.self) { CategoryDetailView(category: $0) }
            .toolbar(.hidden, for: .windowToolbar)
        }
        .onAppear { if store.results.isEmpty && !store.scanning { store.scan() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Neuralyzer").font(.system(size: 34, weight: .bold))
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
