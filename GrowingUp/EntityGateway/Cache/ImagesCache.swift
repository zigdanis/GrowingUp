//
//  ImagesCache.swift
//  GrowingUp
//
//  Created by zigdanis on 17/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit
import Disk

enum ImagesCache {

	static func loadImageFromDisk(image: PersonImage, completion: @escaping (UIImage?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			let image = try? Disk.retrieve(image.cachingKey, from: .documents, as: UIImage.self)
			DispatchQueue.main.async(execute: {
				completion(image)
			})
		}
	}
}
