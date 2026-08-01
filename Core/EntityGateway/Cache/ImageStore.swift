//
//  ImageStore.swift
//  Core
//
//  Copyright © 2026 Danis Ziganshin.
//

import Disk
import Foundation

public protocol ImageStore {
	func save(_ image: PersonImage) async throws
	func delete(_ image: PersonImage) async throws
}

public final class DiskImageStore: ImageStore {

	private let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)

	public init() {}

	public func save(_ image: PersonImage) async throws {
		guard let uiImage = image.uiImage else { throw CoreError.missingValue }
		try Disk.save(uiImage, to: directory, as: image.cachingKey)
		ImagesCache.memoryCache.setValue(uiImage, forKey: image.cachingKey, expires: Date().addingTimeInterval(200))
	}

	public func delete(_ image: PersonImage) async throws {
		ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
		try Disk.remove(image.cachingKey, from: directory)
	}
}
