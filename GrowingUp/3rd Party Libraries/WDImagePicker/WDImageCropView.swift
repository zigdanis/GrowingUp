//
//  WDImageCropView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit
import QuartzCore

private class ScrollView: UIScrollView {
    fileprivate override func layoutSubviews() {
        super.layoutSubviews()

        if let zoomView = self.delegate?.viewForZooming?(in: self) {
            let boundsSize = self.bounds.size
            var frameToCenter = zoomView.frame

            // center horizontally
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            // center vertically
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            zoomView.frame = frameToCenter
        }
    }
}

class WDImageCropView: UIView, UIScrollViewDelegate {

    private let scrollView = ScrollView()
    private let imageView = UIImageView()
	private let cropOverlayView = WDImageCropOverlayView()
    private var xOffset: CGFloat = 0
    private var yOffset: CGFloat = 0
	private let cropSize: CGSize
	private let imageToCrop: UIImage

	init(imageToCrop: UIImage, cropSize: CGSize) {
		self.imageToCrop = imageToCrop
		self.cropSize = cropSize
		super.init(frame: .zero)
		isUserInteractionEnabled = true
		backgroundColor = UIColor.black

		setupScrollView()
		setupImageView()
		setupCropOverlay()
	}

	@available(iOS, unavailable, message: "Class does not intended to be created from xib")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupScrollView() {
		scrollView.contentInsetAdjustmentBehavior = .never
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.showsVerticalScrollIndicator = false
		scrollView.delegate = self
		scrollView.clipsToBounds = false
		scrollView.decelerationRate = .init(rawValue: 0)
		scrollView.backgroundColor = UIColor.clear
		scrollView.minimumZoomScale = 0.5
		scrollView.maximumZoomScale = 20
		scrollView.setZoomScale(1.0, animated: false)
		scrollView.translatesAutoresizingMaskIntoConstraints = false
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
		let consts = [
			imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
			imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			scrollView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

	private func setupCropOverlay() {
		cropOverlayView.cropSize = cropSize
		cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(cropOverlayView)
		let consts = [
			cropOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
			cropOverlayView.topAnchor.constraint(equalTo: topAnchor),
			trailingAnchor.constraint(equalTo: cropOverlayView.trailingAnchor),
			bottomAnchor.constraint(equalTo: cropOverlayView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		return scrollView
	}

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = self.cropSize
        let toolbarSize = CGFloat(UIDevice.current.userInterfaceIdiom == .pad ? 0 : 54)
        self.xOffset = floor((self.bounds.width - size.width) * 0.5)
        self.yOffset = floor((self.bounds.height - toolbarSize - size.height) * 0.5)

        let height = self.imageToCrop.size.height
        let width = self.imageToCrop.size.width

        var factor: CGFloat = 0
        var factoredHeight: CGFloat = 0
        var factoredWidth: CGFloat = 0

        if width > height {
            factor = width / size.width
            factoredWidth = size.width
            factoredHeight =  height / factor
        } else {
            factor = height / size.height
            factoredWidth = width / factor
            factoredHeight = size.height
        }

        self.cropOverlayView.frame = self.bounds
        self.scrollView.frame = CGRect(x: xOffset, y: yOffset, width: size.width, height: size.height)
        self.scrollView.contentSize = CGSize(width: size.width, height: size.height)
        self.imageView.frame = CGRect(x: 0, y: floor((size.height - factoredHeight) * 0.5),
            width: factoredWidth, height: factoredHeight)
    }

	// MARK: - UIScrollView Delegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
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
