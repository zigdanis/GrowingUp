//
//  PersonImage.swift
//  GrowingUp
//
//  Created by zigdanis on 31/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation
import UIKit

public struct PersonImage: Equatable {
	public var id: UUID
	public var uiImage: UIImage?
	public var cachingKey: String {
		return id.uuidString + ".jpg"
	}

	public init(id: UUID? = nil, uiImage: UIImage? = nil) {
		self.id = id ?? UUID()
		self.uiImage = uiImage
	}

	public init?(id: UUID?) {
		guard let id = id else { return nil }
		self.id = id
		self.uiImage = nil
	}
}

public struct PersonImages {
	public var appPic: PersonImage?
	public var widgetPic: PersonImage?

	public init(
		appPic: PersonImage?,
		widgetPic: PersonImage?
	) {
		self.appPic = appPic
		self.widgetPic = widgetPic
	}

	public static func emptyImages() -> PersonImages {
		return PersonImages(appPic: nil, widgetPic: nil)
	}
}
