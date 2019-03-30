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
	private let cropSize: CGSize
	private let imageToCrop: UIImage

	private var imageTop: NSLayoutConstraint!
	private var imageLeading: NSLayoutConstraint!
	private var imageTrailing: NSLayoutConstraint!
	private var imageBottom: NSLayoutConstraint!

	init(imageToCrop: UIImage, cropSize: CGSize) {
		self.imageToCrop = imageToCrop
		self.cropSize = cropSize
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
		imageLeading = imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
		imageTop = imageView.topAnchor.constraint(equalTo: scrollView.topAnchor)
		imageTrailing = scrollView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
		imageBottom = scrollView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
		let consts: [NSLayoutConstraint] = [
			imageTop, imageLeading, imageTrailing, imageBottom
		]
		NSLayoutConstraint.activate(consts)
		imageView.layoutIfNeeded()
	}

	private func setupInitialPositionForScrollView() {
		let widthScale = scrollView.bounds.width / imageView.bounds.width
		let heightScale = scrollView.bounds.height / imageView.bounds.height
		let minSufficientScale = max(widthScale, heightScale)

		scrollView.minimumZoomScale = minSufficientScale
		scrollView.zoomScale = minSufficientScale * 1.1
	}

	private func centerScrollViewContent() {
		let xOffset = (imageView.frame.width - scrollView.bounds.width) / 2
		let yOffset = (imageView.frame.height - scrollView.bounds.height) / 2
		let offset = CGPoint(x: xOffset, y: yOffset)
		scrollView.contentOffset = offset
	}

	// MARK: - Business Logic

    func croppedImage() -> UIImage {
        // Calculate rect that needs to be cropped
        var visibleRect = calcVisibleRectForCropArea()

        // transform visible rect to image orientation
        let rectTransform = orientationTransformedRectOfImage(imageToCrop)
        visibleRect = visibleRect.applying(rectTransform)

        // finally crop image
        let imageRef = imageToCrop.cgImage?.cropping(to: visibleRect)
        let result = UIImage(cgImage: imageRef!, scale: imageToCrop.scale,
            orientation: imageToCrop.imageOrientation)

        return result
    }

    private func calcVisibleRectForCropArea() -> CGRect {
        // scaled width/height in regards of real width to crop width
        let scaleWidth = imageToCrop.size.width / cropSize.width
        let scaleHeight = imageToCrop.size.height / cropSize.height
        var scale: CGFloat = 0

        if cropSize.width == cropSize.height {
            scale = max(scaleWidth, scaleHeight)
        } else if cropSize.width > cropSize.height {
            scale = imageToCrop.size.width < imageToCrop.size.height ?
                max(scaleWidth, scaleHeight) :
                min(scaleWidth, scaleHeight)
        } else {
            scale = imageToCrop.size.width < imageToCrop.size.height ?
                min(scaleWidth, scaleHeight) :
                max(scaleWidth, scaleHeight)
        }

        // extract visible rect from scrollview and scale it
        var visibleRect = scrollView.convert(scrollView.bounds, to: imageView)
        visibleRect = visibleRect.scaleRect(withMultiplier: scale)

        return visibleRect
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
