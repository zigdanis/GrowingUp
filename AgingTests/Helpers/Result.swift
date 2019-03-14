//
//  Result.swift
//  AgingTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Aging

extension Result: Equatable { }

public func ==<T>(lhs: Result<T>, rhs: Result<T>) -> Bool {
    // Shouldn't be used for PRODUCTION enum comparison. Good enough for unit tests.
    return String(stringInterpolationSegment: lhs) == String(stringInterpolationSegment: rhs)
}
