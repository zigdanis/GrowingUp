//
//  CoreDataPerson.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

extension CoreDataPerson {
   
    var person: Person {
        return Person(id: id ?? "", name: name ?? "", birthday: birthdate ?? Date())
    }
    
    func populate(with parameters: AddPersonParameters) {
        id = NSUUID().uuidString
        name = parameters.name
        birthdate = parameters.birthday
    }

}
