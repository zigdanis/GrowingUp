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
        return AddPersonParameters(name: "name", dateOfBirth: Date(), timeOfBirth: Date(), dateComponenets: AddPersonDateComponents())
    }
}

extension AddPersonParameters: Equatable {}

public func == (lhs: AddPersonParameters, rhs: AddPersonParameters) -> Bool {
    return 	lhs.name == rhs.name &&
			lhs.dateOfBirth == rhs.dateOfBirth &&
			lhs.timeOfBirth == rhs.timeOfBirth
}
