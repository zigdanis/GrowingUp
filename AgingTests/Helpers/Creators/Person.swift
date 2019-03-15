//
//  Person.swift
//  AgingTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Aging

extension Person {
    
    static func createPerson() -> Person {
        return Person(id: "0", name: "name", birthday: Date())
    }
}
