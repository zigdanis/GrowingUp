//
//  Person.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct Person: Equatable {
    var id: String
    var name: String
    var birthday: Date
}

struct AddPersonParameters {
    var name: String
    var birthday: Date
}
