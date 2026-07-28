//
//  Constants.swift
//  GrowingUp
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation
import UIKit

extension UIColor {
	static let appColor = #colorLiteral(red: 0.2235294118, green: 0.7411764706, blue: 0.8980392157, alpha: 1)
	static let lightBg = UIColor.white
	static let darkBg = UIColor.black

	static func bgColor(for traitCollection: UITraitCollection) -> UIColor {
		let isLight = traitCollection.userInterfaceStyle == .light
		return isLight ? .lightBg : .darkBg
	}
}
