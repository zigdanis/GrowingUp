//
//  CoreError.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct CoreError: Error, Equatable {
    var localizedDescription: String {
        return message
    }
    var title = ""
    var message = ""

    init(title: String = "Error", message: String) {
        self.title = title
        self.message = message
    }

	static let noNameValue = CoreError(message: "Can't save person without specified name")
	static let noDayValue = CoreError(message: "Can't save person without specified day of birth")
	static let noTimeValue = CoreError(message: "Can't save person without specified time of birth")
	static let coreDataAddFailed = CoreError(message: "Failed adding entity to the data base")
	static let coreDataFetchFailed = CoreError(message: "Failed retrieving entities from the data base")
	static let coreDataSaveFailed = CoreError(message: "Failed saving the context")
	static let asyncWorkError = CoreError(message: "Asyncronous work were not finished before final notification called")
	static let missingValue = CoreError(message: "Missing value")
	static let unknownError = CoreError(message: "Unknown error occured")
}
