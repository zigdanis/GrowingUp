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

public enum ImagesCache {

	public static func loadImageFromDisk(image: PersonImage, completion: @escaping (UIImage?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
			let image = try? Disk.retrieve(image.cachingKey, from: directory, as: UIImage.self)
			DispatchQueue.main.async(execute: {
				completion(image)
			})
		}
	}
}
