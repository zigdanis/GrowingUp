//
//  ImageCaptureFlowView.swift
//  GrowingUp
//
//  Root of the image-pick flow hosted into the UIKit EditPerson scene.
//  PR1: photo library -> crop -> confirm. A camera source is added in PR2 by
//  inserting a source chooser ahead of the grid; the seam contract
//  (`onComplete(UIImage)` / `onCancel`) stays the same.
//

import SwiftUI

struct ImageCaptureFlowView: View {
    let cropShape: CropShape
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var pickedImage: IdentifiableImage?

    var body: some View {
        NavigationStack {
            PhotoGridView { image in
                pickedImage = IdentifiableImage(image: image)
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .fullScreenCover(item: $pickedImage) { item in
            CropStep(
                image: item.image,
                shape: cropShape,
                onComplete: { cropped in
                    pickedImage = nil
                    onComplete(cropped.downsized(maxPixelSide: cropShape.maxPixelSize))
                },
                onCancel: {
                    // Back to the grid to choose another photo.
                    pickedImage = nil
                }
            )
        }
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
