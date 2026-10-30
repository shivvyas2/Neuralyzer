import NeuralyzerKit
import SwiftUI

/// What Neuralyzer suggests cleaning, at the top of Home.
struct RecommendedCard: View {
    @Environment(ScanStore.self) private var store
    @State private var hovering = false

    var body: some View {
        let recs = store.recommended
        let total = recs.reduce(Int64(0)) { $0 + $1.bytes }
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended").font(Theme.title(28)).foregroundStyle(Theme.ink)
                Text("\(formatBytes(total)) safe to clean").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(recs.prefix(4)) { r in
                    HStack(spacing: 18) {
                        Text(r.reason).lineLimit(1)
                        Spacer(minLength: 12)
                        Text(formatBytes(r.bytes)).monospacedDigit()
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                }
            }
            .frame(maxWidth: 420)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Theme.yellow))
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
        .offset(y: hovering ? -3 : 0)
        .shadow(color: .black.opacity(hovering ? 0.14 : 0.07), radius: hovering ? 16 : 10, y: 6)
        .animation(.smooth(duration: 0.2), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(shape)
    }
}

/// Every recommendation with its items; one button cleans what is checked.
struct RecommendedView: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        let recs = store.recommended
        let selected = recs.flatMap(\.items).filter { store.selection.contains($0.id) }
        let selectedBytes = selected.reduce(Int64(0)) { $0 + $1.bytes }
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.yellow))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.ink, lineWidth: 1.5))
                .foregroundStyle(Theme.ink)
                Text("Recommended").font(Theme.title(34))
                Spacer()
                Button("Select All") { store.selectAllRecommended() }.buttonStyle(QuietButtonStyle())
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(recs) { r in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(r.reason).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text(formatBytes(r.bytes)).font(.system(size: 14)).foregroundStyle(.secondary).monospacedDigit()
                            }
                            ForEach(r.items) { item in
                                ItemRow(item: item, selected: store.selection.contains(item.id)) { store.toggle(item) }
                            }
                        }
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
        .onChange(of: recs.isEmpty) { _, empty in if empty && !store.scanning { dismiss() } }
    }
}
