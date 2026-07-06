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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Photo"))
        .task(id: asset.id) {
            let pixels = side * displayScale
            image = await viewModel.thumbnail(
                for: asset,
                targetSize: CGSize(width: pixels, height: pixels)
            )
        }
    }
}
