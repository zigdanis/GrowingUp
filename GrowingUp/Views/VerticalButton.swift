//
//  VerticalButton.swift
//  GrowingUp
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
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
		var configuration = configuration ?? .plain()
		configuration.imagePlacement = .top
		configuration.imagePadding = 6
		self.configuration = configuration
	}
}
