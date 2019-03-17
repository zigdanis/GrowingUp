//
//  Person.swift
//  GrowingUp
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

struct AddPersonDateComponents {
    var years = true
    var months = true
    var days = true
    var hours = true
    var minutes = true
    var seconds = true
}
