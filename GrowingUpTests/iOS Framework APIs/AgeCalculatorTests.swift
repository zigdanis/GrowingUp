//
//  AgeCalculatorTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core

class AgeCalculatorTests: XCTestCase {

  func test_AgeForDateContainingAllComponents() {
    // Given
    let then = DateComponents(year: 1989, month: 12, day: 6, hour: 6, minute: 15, second: 20)
    let now = DateComponents(year: 2019, month: 4, day: 14, hour: 20, minute: 34, second: 40)
    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: then, to: now)
    let expectedAge = "29 years 4 months 8 days 14 hours 19 minutes 20 seconds"
    // When
    let age = AgeCalculator.ageString(for: components)
    // Then
    XCTAssertEqual(age, expectedAge, "Failed to receive expected age string")
  }

}
