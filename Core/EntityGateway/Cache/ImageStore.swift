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

	private static let queue = DispatchQueue(label: "com.zigdanis.GrowingUp.image-store", qos: .utility)
	private let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)

	public init() {}

	public func save(_ image: PersonImage) async throws {
		guard let uiImage = image.uiImage else { throw CoreError.missingValue }
		try await withCheckedThrowingContinuation { continuation in
			Self.queue.async {
				do {
					try Disk.save(uiImage, to: self.directory, as: image.cachingKey)
					DispatchQueue.main.sync {
						ImagesCache.memoryCache.setValue(
							uiImage,
							forKey: image.cachingKey,
							expires: Date().addingTimeInterval(200))
					}
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	public func delete(_ image: PersonImage) async throws {
		try await withCheckedThrowingContinuation { continuation in
			Self.queue.async {
				DispatchQueue.main.sync {
					ImagesCache.memoryCache.removeValue(forKey: image.cachingKey)
				}
				do {
					try Disk.remove(image.cachingKey, from: self.directory)
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
}
