//
//  ToggleCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 28/06/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol ToggleCellPresenter: AnyObject {
  func configure(cell: ToggleCellView, forRow row: Int)
  func valueFor(row: Int, didChangeTo value: Bool)
  func valueFor(row: Int) -> Bool
}

final class ToggleCellPresenterImplementation: ToggleCellPresenter {
  private var storage = [Int: Bool]()
  weak var toggleDelegate: ToggleCellDelegate?

  func configure(cell: ToggleCellView, forRow row: Int) {
    cell.setup(with: toggleDelegate, forRow: row)
    cell.display(title: String(localized: "Add to Widget"))
    guard let value = storage[row] else { return }
    cell.display(isOn: value, animated: false)
  }

  func valueFor(row: Int, didChangeTo value: Bool) {
    storage[row] = value
  }

  func valueFor(row: Int) -> Bool {
    return storage[row] ?? false
  }
}
