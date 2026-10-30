import NeuralyzerKit
import SwiftUI

struct CategoryDetailView: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let category: CategoryID
    @State private var confirming = false

    var body: some View {
        let items = store.items(in: category)
        let selected = store.selectedItems(in: category)
        let selectedBytes = selected.reduce(Int64(0)) { $0 + $1.bytes }
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Color("Surface")))
                .overlay(Circle().strokeBorder(.primary.opacity(0.08)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title).font(.system(size: 30, weight: .bold))
                    Text(formatBytes(items.reduce(0) { $0 + $1.bytes }))
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(allSelected(items) ? "Select None" : "Select All") { toggleAll(items) }
                    .buttonStyle(QuietButtonStyle())
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        ItemRow(item: item, selected: store.selection.contains(item.id)) { store.toggle(item) }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            HStack {
                Spacer()
                Button("Clean \(formatBytes(selectedBytes))") { confirming = true }
                    .buttonStyle(PillButtonStyle())
                    .disabled(selected.isEmpty)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(isPresented: $confirming) { CleanSheet(items: selected) }
        .onChange(of: items.isEmpty) { _, empty in if empty && !store.scanning { dismiss() } }
    }

    private func allSelected(_ items: [Item]) -> Bool {
        !items.isEmpty && items.allSatisfy { store.selection.contains($0.id) }
    }

    private func toggleAll(_ items: [Item]) {
        let ids = items.map(\.id)
        if allSelected(items) { store.selection.subtract(ids) } else { store.selection.formUnion(ids) }
    }
}
