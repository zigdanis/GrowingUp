//
//  Person.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

extension Person {

    static func createPerson() -> Person {
        return Person(id: UUID(), name: "name", birthday: Date(), appPicId: UUID(), widgetPicId: UUID())
    }
}
