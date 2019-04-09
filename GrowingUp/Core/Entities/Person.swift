//
//  Person.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct Person: Equatable, Hashable {
	var id: UUID
    var name: String
    var birthday: Date
}
