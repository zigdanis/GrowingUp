//
//  WDImageCropView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit
import QuartzCore

class WDImageCropView: UIView {

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var xOffset: CGFloat = 0
    private var yOffset: CGFloat = 0
	private let cropSize = UIScreen.main.bounds.size
	private let imageToCrop: UIImage

	init(imageToCrop: UIImage) {
		self.imageToCrop = imageToCrop
		super.init(frame: .zero)

		isUserInteractionEnabled = true
		backgroundColor = UIColor.black
		setupScrollView()
		setupImageView()
	}

	@available(iOS, unavailable, message: "Class does not intended to be created from xib")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		setupInitialPositionForScrollView()
		centerScrollViewContent()
	}

	private func setupScrollView() {
		scrollView.contentInsetAdjustmentBehavior = .never
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.showsVerticalScrollIndicator = false
		scrollView.delegate = self
		scrollView.clipsToBounds = true
		scrollView.decelerationRate = .init(rawValue: 0)
		scrollView.backgroundColor = UIColor.clear
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.alwaysBounceVertical = true
		scrollView.alwaysBounceHorizontal = true
		addSubview(scrollView)
		let consts = [
			scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
			scrollView.topAnchor.constraint(equalTo: topAnchor),
			trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
			bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

	private func setupImageView() {
		imageView.image = imageToCrop
		imageView.contentMode = .scaleAspectFit
		imageView.backgroundColor = UIColor.black
		imageView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.addSubview(imageView)
		let consts: [NSLayoutConstraint] = [
			imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
		imageView.layoutIfNeeded()
	}

	private func setupInitialPositionForScrollView() {
		let widthScale = scrollView.bounds.width / imageView.bounds.width
		let heightScale = scrollView.bounds.height / imageView.bounds.height
		let minSufficientScale = max(widthScale, heightScale)

		scrollView.minimumZoomScale = minSufficientScale
		scrollView.maximumZoomScale = max(1, minSufficientScale * 1.1)
		scrollView.zoomScale = minSufficientScale * 1.1
	}

	private func centerScrollViewContent() {
		let xOffset = (imageView.frame.width - scrollView.bounds.width) / 2
		let yOffset = (imageView.frame.height - scrollView.bounds.height) / 2
		let offset = CGPoint(x: xOffset, y: yOffset)
		scrollView.contentOffset = offset
	}

	// MARK: - Business Logic

    func croppedAndScaledImage() throws -> UIImage {
        var visibleRect = calcVisibleRectForCropArea()
        let rectTransform = orientationTransformedRectOfImage(imageToCrop)
        visibleRect = visibleRect.applying(rectTransform)
		guard let imageRef = imageToCrop.cgImage?.cropping(to: visibleRect) else {
			throw WDImageError.imageCropFailed
		}
		guard let scaledRef = scaled(cgImage: imageRef) else {
			throw WDImageError.imageScaleFailed
		}
        let img = UIImage(cgImage: scaledRef, scale: imageToCrop.scale,
            orientation: imageToCrop.imageOrientation)
		return img
    }

	private func scaled(cgImage: CGImage) -> CGImage? {
		let scale = UIScreen.main.scale
		let width = min(Int(cropSize.width * scale), cgImage.width)
		let height = min(Int(cropSize.height * scale), cgImage.height)
		let bitsPerComponent = cgImage.bitsPerComponent
		let bytesPerRow = width * cgImage.bitsPerPixel / 8
		guard let colorSpace = cgImage.colorSpace else { return nil }
		let bitmapInfo = CGBitmapInfo(rawValue: 5)

		let context = CGContext(data: nil,
									  width: width,
									  height: height,
									  bitsPerComponent: bitsPerComponent,
									  bytesPerRow: bytesPerRow,
									  space: colorSpace,
									  bitmapInfo: bitmapInfo.rawValue)
		context?.interpolationQuality = .high
		let scaledSize = CGSize(width: width, height: height)
		let rect = CGRect(origin: .zero, size: scaledSize)
		context?.draw(cgImage, in: rect)
		let img = context?.makeImage()
		return img
	}

    private func calcVisibleRectForCropArea() -> CGRect {
		let scale = 1 / scrollView.zoomScale
        return scrollView.bounds.scaleRect(withMultiplier: scale)
    }

    private func orientationTransformedRectOfImage(_ image: UIImage) -> CGAffineTransform {
        var rectTransform: CGAffineTransform!

        switch image.imageOrientation {
        case .left:
            rectTransform = CGAffineTransform(rotationAngle: CGFloat(Float.pi/2)).translatedBy(x: 0, y: -image.size.height)
        case .right:
            rectTransform = CGAffineTransform(rotationAngle: CGFloat(-Float.pi/2)).translatedBy(x: -image.size.width, y: 0)
        case .down:
            rectTransform = CGAffineTransform(rotationAngle: CGFloat(-Float.pi)).translatedBy(x: -image.size.width, y: -image.size.height)
        default:
            rectTransform = CGAffineTransform.identity
        }

        return rectTransform.scaledBy(x: image.scale, y: image.scale)
    }
}

extension WDImageCropView: UIScrollViewDelegate {

	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return imageView
	}

}
