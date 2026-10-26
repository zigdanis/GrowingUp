import Disk
import Foundation

public final class DiskImageStore: @unchecked Sendable, ImageStore {
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

	/// Writes the original without keeping it in the memory cache: at up to 4096 pixels a side it is far larger than a
	/// picture, and only framing a picture reads it again.
	public func saveOriginal(_ image: PersonImage) async throws {
		try await withCheckedThrowingContinuation { continuation in
			Self.queue.async {
				do {
					let file = try OriginalPhotoFile.encode(image)
					try Disk.save(file.data, to: self.directory, as: file.name)
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
					for key in image.storedCachingKeys where Disk.exists(key, in: self.directory) {
						try Disk.remove(key, from: self.directory)
					}
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
}
