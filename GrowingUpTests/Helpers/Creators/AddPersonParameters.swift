//
//  AddPersonParameters.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

extension AddPersonParameters {
    static func createParameters() -> AddPersonParameters {
        return AddPersonParameters(name: "name", dayOfBirth: Date(), timeOfBirth: Date(), dateComponenets: AddPersonDateComponents())
    }
}
