//
//  CoreError.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct CoreError: Error {
    var localizedDescription: String {
        return message
    }
    var title = ""
    var message = ""

    init(title: String = "", message: String) {
        self.title = title
        self.message = message
    }

	static let noNameValue = CoreError(title: "Error", message: "Can't save person without specified name")
	static let noDayValue = CoreError(title: "Error", message: "Can't save person without specified day of birth")
	static let noTimeValue = CoreError(title: "Error", message: "Can't save person without specified time of birth")
}
