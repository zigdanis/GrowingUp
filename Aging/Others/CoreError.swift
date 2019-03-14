//
//  CoreError.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct CoreError: Error {
    var localizedDescription: String {
        return message
    }
    
    var message = ""
}
