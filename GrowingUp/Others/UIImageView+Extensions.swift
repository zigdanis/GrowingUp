//
//  UIImageView+Extensions.swift
//  GrowingUp
//
//  Created by zigdanis on 14/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit
import Disk

extension UIImageView {

	func setCachedImage(key: String) {
		DispatchQueue.global(qos: .userInitiated).async {
			let image = try? Disk.retrieve(key, from: .documents, as: UIImage.self)
			DispatchQueue.main.async(execute: {
				self.image = image
			})
		}
	}
}
