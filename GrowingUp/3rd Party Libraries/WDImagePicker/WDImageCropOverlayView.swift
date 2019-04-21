//
//  WDImageCropOverlayView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

final class WDImageCropOverlayView: UIView {

    private let cropSize: CropSize
	private var croppingSize: CGSize {
		switch cropSize {
		case .screen: return UIScreen.main.bounds.size
		case .circle: return circleSize()
		}
	}

	init(cropSize: CropSize) {
		self.cropSize = cropSize
		super.init(frame: .zero)
		backgroundColor = UIColor.clear
		isUserInteractionEnabled = false
	}

	@available(iOS, unavailable, message: "Use init(cropSize:) instead")
    override init(frame: CGRect) {
		fatalError("Use init(cropSize:) instead")
    }

	@available(iOS, unavailable, message: "Use init(cropSize:) instead")
    required init?(coder aDecoder: NSCoder) {
		fatalError("Use init(cropSize:) instead")
    }

    override func draw(_ rect: CGRect) {

        let width = rect.width
        let height = rect.height

        let heightSpan = floor(height / 2 - croppingSize.height / 2)
        let widthSpan = floor(width / 2 - croppingSize.width / 2)
		let squareInCenter = CGRect(origin: CGPoint(x: widthSpan, y: heightSpan),
									size: croppingSize)
		let arcPath = CGPath(ellipseIn: squareInCenter, transform: nil)
		let bezier = UIBezierPath(cgPath: arcPath)

		let clip = UIBezierPath(rect: rect)
		clip.append(bezier.reversing())
		clip.addClip()

        UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).set()
		UIRectFill(rect)
		UIColor.white.set()
		bezier.stroke()
    }

	// MARK: - Helpers

	private func circleSize() -> CGSize {
		let side = UIScreen.main.bounds.width * 0.75
		return CGSize(width: side, height: side)
	}
}
