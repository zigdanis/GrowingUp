//
//  CropStep.swift
//  GrowingUp
//
//  Swap-seam around the crop engine. The rest of the flow depends only on this
//  contract — (source image + slot shape) in, cropped image out — so the crop
//  implementation (currently SwiftyCrop) can be replaced without ripple.
//

import SwiftUI
import SwiftyCrop

struct CropStep: View {
    let image: UIImage
    let shape: CropShape
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    var body: some View {
        SwiftyCropView(
            imageToCrop: image,
            maskShape: shape.maskShape,
            configuration: configuration,
            onCancel: onCancel
        ) { cropped in
            if let cropped {
                onComplete(cropped)
            } else {
                onCancel()
            }
        }
    }

    private var configuration: SwiftyCropConfiguration {
        SwiftyCropConfiguration(
            maxMagnificationScale: 6.0,
            cropImageCircular: shape.cropCircular,
            rectAspectRatio: shape.aspectRatio,
            allowAspectRatioResizing: false,
            colors: SwiftyCropConfiguration.Colors(
                saveButtonBackground: .accentColor
            )
        )
    }
}
