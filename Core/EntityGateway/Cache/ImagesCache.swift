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

	public static func loadImageFromDisk(image: PersonImage, completion: @escaping (Result<UIImage, CoreError>) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
			do {
				let image = try Disk.retrieve(image.cachingKey, from: directory, as: UIImage.self)
				DispatchQueue.main.async(execute: {
					completion(.success(image))
				})
			} catch {
				let err = error as? CoreError ?? CoreError(message: error.localizedDescription)
				DispatchQueue.main.async(execute: {
					completion(.failure(err))
				})
			}
		}
	}
}
