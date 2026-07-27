//
//  EmptyPersonPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core
@testable import GrowingUp

class EmptyPersonPresenterTests: XCTestCase {

  var sut: EmptyPersonPresenterImplementation!
  let routerSpy = EmptyPersonViewRouterSpy()
  let delegateSpy = EditPersonPresenterDelegateSpy()

  override func setUp() {
    sut = EmptyPersonPresenterImplementation(router: routerSpy, addPersonPresenterDelegate: delegateSpy)
  }

  func test_SUT_WhenCalledAddButtonPressed_ShouldCallRouter() {
    // When
    sut.addButtonPressed()
    // Then
    XCTAssertTrue(routerSpy.didCallPresentAddPerson, "Expected to receive a call in Router")
  }

}
