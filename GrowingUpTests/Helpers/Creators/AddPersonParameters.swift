//
//  AddPersonParameters.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit
@testable import GrowingUp
@testable import Core

extension AddPersonParameters {
    static func createParameters() -> AddPersonParameters {
		let appPic = PersonImage()
		let widgetPic = PersonImage()
		return AddPersonParameters(name: "John Snow", dayOfBirth: Date(), timeOfBirth: Date(), appImage: appPic, widgetImage: widgetPic, isOnWidget: true, createdDate: Date())
    }
}
