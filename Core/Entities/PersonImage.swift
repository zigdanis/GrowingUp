//
//  PersonImage.swift
//  GrowingUp
//
//  Created by zigdanis on 31/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation
import UIKit

public struct PersonImage: @unchecked Sendable, Equatable {
	public var id: UUID
	public var uiImage: UIImage?
	/// The region of the person's original photo this picture shows; nil for the original itself, and for a picture
	/// framed before originals were kept, whose region is unknown.
	public var crop: PhotoCrop?
	public var cachingKey: String {
		return id.uuidString + ".png"
	}

	/// Previous releases stored JPEGs under this key. Keep it for reading and removing existing photos.
	var legacyCachingKey: String {
		id.uuidString + ".jpg"
	}

	/// An original photo is kept as HEIC where the device can encode it; see `OriginalPhotoFile`.
	var originalCachingKey: String {
		id.uuidString + ".heic"
	}

	/// Every key a picture may be stored under, so removing it leaves no file behind.
	var storedCachingKeys: [String] {
		[cachingKey, originalCachingKey, legacyCachingKey]
	}

	public init(id: UUID? = nil, uiImage: UIImage? = nil, crop: PhotoCrop? = nil) {
		self.id = id ?? UUID()
		self.uiImage = uiImage
		self.crop = crop
	}

	public init?(id: UUID?, crop: PhotoCrop? = nil) {
		guard let id = id else { return nil }
		self.id = id
		self.uiImage = nil
		self.crop = crop
	}
}
