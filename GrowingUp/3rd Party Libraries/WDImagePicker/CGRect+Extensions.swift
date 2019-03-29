//
//  CGRect+Helpers.swift
//  GrowingUp
//
//  Created by zigdanis on 29/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import CoreGraphics

extension CGRect {

	func scaleRect(withMultiplier multiplier: CGFloat) -> CGRect {
		return CGRect(
			x: origin.x * multiplier,
			y: origin.y * multiplier,
			width: size.width * multiplier,
			height: size.height * multiplier)
	}
}
