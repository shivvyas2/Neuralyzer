import NeuralyzerPhoneKit
import Photos
import SwiftUI

/// Thumbnails. Duplicate groups show the kept copy marked "Keep"; tap any other to toggle it.
struct PhotoGridView: View {
    @Environment(PhoneStore.self) private var store
    let content: CategoryContent
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        if content.photoGroups.isEmpty {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(content.photos) { tile($0, keep: false) }
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(content.photoGroups, id: \.keep.id) { group in
                    LazyVGrid(columns: columns, spacing: 6) {
                        tile(group.keep, keep: true)
                        ForEach(group.others) { tile($0, keep: false) }
                    }
                }
            }
        }
    }

    private func tile(_ photo: PhotoInfo, keep: Bool) -> some View {
        let selected = store.selection.contains(photo.id)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Thumbnail(id: photo.id)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: selected ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                if keep {
                    Text("Keep")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(.white))
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.2))
                        .padding(6)
                } else {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? Theme.ink : .white)
                        .background(Circle().fill(selected ? .white : .black.opacity(0.2)))
                        .padding(6)
                }
            }
            .contentShape(shape)
            .onTapGesture { if !keep { store.toggle(photo.id) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(keep ? "Kept copy" : (photo.isVideo ? "Video" : "Photo"))
            .accessibilityValue(keep ? "" : (selected ? "Selected" : "Not selected"))
            .accessibilityAddTraits(keep ? [] : [.isButton])
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// A local thumbnail; never downloads from iCloud.
struct Thumbnail: View {
    let id: String
    @State private var image: UIImage?

    var body: some View {
        Color(white: 0.93)
            .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
            .task(id: id) {
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = false
                options.deliveryMode = .opportunistic
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { img, _ in
                    if let img { image = img }
                }
            }
    }
}
