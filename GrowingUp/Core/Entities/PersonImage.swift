//
//  PersonImage.swift
//  GrowingUp
//
//  Created by zigdanis on 31/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

struct PersonImage: Equatable {
	var id: UUID
	var uiImage: UIImage?
	var cachingKey: String {
		return id.uuidString + ".jpg"
	}

	init(id: UUID? = nil, uiImage: UIImage? = nil) {
		self.id = id ?? UUID()
		self.uiImage = uiImage
	}

	init?(id: UUID?) {
		guard let id = id else { return nil }
		self.id = id
		self.uiImage = nil
	}
}

struct PersonImages {
	var appPic: PersonImage?
	var widgetPic: PersonImage?

	static func emptyImages() -> PersonImages {
		return PersonImages(appPic: nil, widgetPic: nil)
	}
}
