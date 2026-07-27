//
//  PhotoThumbnailCell.swift
//  GrowingUp
//
//  One square cell in the photo grid. Takes only what it renders (its asset),
//  loads its own thumbnail, and reports taps upward.
//

import SwiftUI

struct PhotoThumbnailCell: View {
    let asset: PhotoAsset
    let side: CGFloat
    let viewModel: PhotoGridViewModel
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.displayScale)
    private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color(.secondarySystemBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Text("1")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue, in: Circle())
                        .overlay { Circle().stroke(.white, lineWidth: 2) }
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Photo"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: asset.id) {
            let pixels = side * displayScale
            image = await viewModel.thumbnail(
                for: asset,
                targetSize: CGSize(width: pixels, height: pixels)
            )
        }
    }
}
