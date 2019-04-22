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

	private let cropSize: CropSize
	private let overlayView: WDImageCropOverlayView
	private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var xOffset: CGFloat = 0
    private var yOffset: CGFloat = 0
	private let imageToCrop: UIImage
	private var croppingSize: CGSize {
		switch cropSize {
		case .screen: return UIScreen.main.bounds.size
		case .circle: return circleRect().size
		}
	}

	init(imageToCrop: UIImage, cropSize: CropSize) {
		self.cropSize = cropSize
		self.imageToCrop = imageToCrop
		self.overlayView = WDImageCropOverlayView(cropSize: cropSize)
		super.init(frame: .zero)

		isUserInteractionEnabled = true
		backgroundColor = UIColor.black
		setupScrollView()
		setupImageView()
		setupOverlayView()
	}

	@available(iOS, unavailable, message: "Class does not intended to be created from xib")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		setupZoomScaleForScrollView()
		centerScrollViewContent()
		setupScrollViewInsets()
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

	private func setupOverlayView() {
		guard cropSize == .circle else { return }
		overlayView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(overlayView)
		let consts = [
			overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
			overlayView.topAnchor.constraint(equalTo: topAnchor),
			trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
			bottomAnchor.constraint(equalTo: overlayView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

	// MARK: - UIScrollView Setup

	private func setupZoomScaleForScrollView() {
		let croppingWidth = croppingSize.width
		let croppingHeight = croppingSize.height
		let widthScale = croppingWidth / imageView.bounds.width
		let heightScale = croppingHeight / imageView.bounds.height
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

	private func setupScrollViewInsets() {
		let croppingRect = cropSize == .circle ? circleRect() : bounds
		let top = croppingRect.minY
		let left = croppingRect.minX
		let bottom = scrollView.bounds.height - croppingRect.maxY
		let right = scrollView.bounds.width - croppingRect.maxX
		let insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
		scrollView.contentInset = insets
	}

	// MARK: - Business Logic

    func croppedAndScaledImage() throws -> UIImage {
        var visibleRect = calcVisibleRectForCropArea()
        let rectTransform = orientationTransformedRectOfImage(imageToCrop)
        visibleRect = visibleRect.applying(rectTransform)
		guard let imageRef = imageToCrop.cgImage?.cropping(to: visibleRect) else {
			throw WDImageError.imageCropFailed
		}
		let isRotated = imageToCrop.imageOrientation == .left ||
						imageToCrop.imageOrientation == .right ||
						imageToCrop.imageOrientation == .leftMirrored ||
						imageToCrop.imageOrientation == .rightMirrored
		guard let scaledRef = scaled(cgImage: imageRef, rotated: isRotated) else {
			throw WDImageError.imageScaleFailed
		}
        let img = UIImage(cgImage: scaledRef, scale: imageToCrop.scale,
            orientation: imageToCrop.imageOrientation)
		return img
    }

	private func scaled(cgImage: CGImage, rotated: Bool) -> CGImage? {
		let scale = UIScreen.main.scale
		let scalingWidth = rotated ? Int(croppingSize.height * scale) : Int(croppingSize.width * scale)
		let scalingHeight = rotated ? Int(croppingSize.width * scale) : Int(croppingSize.height * scale)
		let width = min(scalingWidth, cgImage.width)
		let height = min(scalingHeight, cgImage.height)
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
		let croppingRect = cropSize == .circle ? circleRect() : bounds
		let result = convert(croppingRect, to: imageView).integral
		return result
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

	private func circleRect() -> CGRect {
		let side = UIScreen.main.bounds.width * 0.75
		let circleSize = CGSize(width: side, height: side)
		let width = circleSize.width
		let height = circleSize.height
		let origin = CGPoint(x: (bounds.width - width) / 2,
							 y: (bounds.height - height) / 2)
		return CGRect(origin: origin, size: circleSize)
	}
}

extension WDImageCropView: UIScrollViewDelegate {

	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return imageView
	}

}
