//
//  CoreDataPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

extension CoreDataPerson {

    var person: Person {
		return Person(id: id ?? UUID(), name: name ?? "", birthday: birthdate ?? Date())
    }

    func populate(with parameters: AddPersonParameters) {
        id = UUID()
        name = parameters.name
        birthdate = parameters.combinedDate()
		appPicId = parameters.appImage?.id
		widgetPicId = parameters.widgetImage?.id
    }

}
