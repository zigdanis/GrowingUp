//
//  AddPersonParameters.swift
//  AgingTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Aging

extension AddPersonParameters {
    static func createParameters() -> AddPersonParameters {
        return AddPersonParameters(name: "name", birthday: Date())
    }
}
