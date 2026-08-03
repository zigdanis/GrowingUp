//
//  ImagesCache.swift
//  GrowingUp
//
//  Created by zigdanis on 17/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Disk
import Foundation
import UIKit

public enum ImagesCache {

	public static let memoryCache = MemoryCache<UIImage>()

	public static func loadImageFromDiskOrMemory(image: PersonImage) async throws -> UIImage {
		try Task.checkCancellation()
		let loadedImage = try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				if let memoryImg = memoryCache.value(forKey: image.cachingKey) {
					continuation.resume(returning: memoryImg)
				} else {
					let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
					do {
						continuation.resume(
							returning: try Disk.retrieve(image.cachingKey, from: directory, as: UIImage.self))
					} catch {
						continuation.resume(throwing: CoreError(error: error))
					}
				}
			}
		}
		try Task.checkCancellation()
		return loadedImage
	}
}
