//
//  Date+Extensions.swift
//  Aging
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

extension Date {
    
    func dateString() -> String {
        return dateFormatter.string(from: self)
    }
    
    func timeString() -> String {
        return timeFormatter.string(from: self)
    }
}
