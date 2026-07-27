//
//  ImagePickersCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Core
import Foundation

protocol ImagesCellPresenter: AnyObject {
  func configure(cell: ImagesCellView, forRow row: Int, with delegate: ImagesCellViewDelegate)
  func valueFor(row: Int, didChangeTo value: PersonImages)
  func valueFor(row: Int) -> PersonImages?
}

class ImagesCellPresenterImplementation: ImagesCellPresenter {

  private var storage = [Int: PersonImages]()

  func configure(cell: ImagesCellView, forRow row: Int, with delegate: ImagesCellViewDelegate) {
    let pics = storage[row]
    cell.display(appPic: pics?.appPic)
    cell.display(widgetPic: pics?.widgetPic)
    cell.setup(with: delegate, forRow: row)
  }

  func valueFor(row: Int, didChangeTo value: PersonImages) {
    storage[row] = value
  }

  func valueFor(row: Int) -> PersonImages? {
    return storage[row]
  }

}
