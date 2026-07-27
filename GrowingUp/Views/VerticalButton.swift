//
//  VerticalButton.swift
//  GrowingUp
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class VerticalButton: UIButton {

	override init(frame: CGRect) {
		super.init(frame: frame)
		sharedInit()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		sharedInit()
	}

	override func prepareForInterfaceBuilder() {
		sharedInit()
	}

	private func sharedInit() {
		centerVertically()
	}

	override var intrinsicContentSize: CGSize {
		return verticalAlignedIntrinsicContentSize()
	}

	private func centerVertically(padding: CGFloat = 6) {
		let imageSize = imageView?.frame.size ?? .zero
		let titleSize = titleLabel?.frame.size ?? .zero

		let totalHeight = imageSize.height + titleSize.height + padding
		let imageTop = -(totalHeight - imageSize.height)
		imageEdgeInsets = UIEdgeInsets(top: imageTop, left: 0, bottom: 0, right: -titleSize.width)

		let titleBottom = -(totalHeight - titleSize.height)
		titleEdgeInsets = UIEdgeInsets(top: 0, left: -imageSize.width, bottom: titleBottom, right: 0)
	}

	private func verticalAlignedIntrinsicContentSize(padding: CGFloat = 6) -> CGSize {
		let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

		if let titleSize = titleLabel?.sizeThatFits(maxSize), let imageSize = imageView?.sizeThatFits(maxSize) {
			let width = ceil(max(imageSize.width, titleSize.width))
			let height = ceil(imageSize.height + titleSize.height + padding)

			return CGSize(width: width, height: height)
		}

		return super.intrinsicContentSize
	}
}
