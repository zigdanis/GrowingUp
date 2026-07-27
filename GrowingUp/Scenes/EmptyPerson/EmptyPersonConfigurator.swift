//
//  EmptyPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EmptyPersonConfigurator {
  func configure(emptyPersonController: EmptyPersonViewController)
}

final class EmptyPersonConfiguratorImplementation: EmptyPersonConfigurator {

  private let index: Int
  private weak var addPersonPresenterDelegate: EditPersonPresenterDelegate?

  init(index: Int, addPersonPresenterDelegate: EditPersonPresenterDelegate) {
    self.index = index
    self.addPersonPresenterDelegate = addPersonPresenterDelegate
  }

  func configure(emptyPersonController: EmptyPersonViewController) {
    let router = EmptyPersonViewRouterImplementation(emptyPersonViewController: emptyPersonController)
    let presenter = EmptyPersonPresenterImplementation(
      router: router, addPersonPresenterDelegate: addPersonPresenterDelegate)
    emptyPersonController.presenter = presenter
    emptyPersonController.index = index
  }
}
