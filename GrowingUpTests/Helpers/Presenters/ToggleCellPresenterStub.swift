//
//  ToggleCellPresenterStub.swift
//  GrowingUpTests
//
//  Created by zigdanis on 08/09/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

@testable import Core
@testable import GrowingUp

final class ToggleCellPresenterStub: ToggleCellPresenter {

  var storage = [Int: Bool]()
  var didCallConfigure = false

  func valueFor(row: Int) -> Bool {
    return storage[row] ?? false
  }

  func valueFor(row: Int, didChangeTo value: Bool) {
    storage[row] = value
  }

  func configure(cell: ToggleCellView, forRow row: Int) {
    didCallConfigure = true
  }

  func toggleValueFor(row: Int, didChangeTo state: Bool) {
    storage[row] = state
  }
}
