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

	init(id: UUID? = nil, uiImage: UIImage? = nil) {
		self.id = id ?? UUID()
		self.uiImage = uiImage
	}
}

struct PersonImages {
	var appPic: PersonImage?
	var widgetPic: PersonImage?

	static func emptyImages() -> PersonImages {
		return PersonImages(appPic: nil, widgetPic: nil)
	}
}
