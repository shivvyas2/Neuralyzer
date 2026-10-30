import NeuralyzerPhoneKit
import SwiftUI

/// Each group shows the names and the phone numbers and emails the merged contact will have.
struct ContactListView: View {
    @Environment(PhoneStore.self) private var store
    let groups: [ContactGroup]

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(groups, id: \.keep.id) { group in
                let selected = store.selection.contains(group.keep.id)
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(([group.keep] + group.others).map(name).joined(separator: ", "))
                            .font(.system(size: 15, weight: .semibold))
                        ForEach(mergedPhones(group) + mergedEmails(group), id: \.self) {
                            Text($0).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                        if !group.sameContainer {
                            Text("In different accounts").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(shape.fill(.white))
                .overlay(shape.strokeBorder(Theme.ink, lineWidth: 1.5))
                .contentShape(shape)
                .onTapGesture { if group.sameContainer { store.toggle(group.keep.id) } }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(group.sameContainer ? [.isButton] : [])
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .opacity(group.sameContainer ? 1 : 0.6)
            }
        }
    }

    private func name(_ c: ContactInfo) -> String {
        let full = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? (c.organization.isEmpty ? "No name" : c.organization) : full
    }
}
