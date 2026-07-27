//
//  EmptyPersonViewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol EmptyPersonViewRouter {
  func presentAddPerson(addPersonPresenterDelegate: EditPersonPresenterDelegate?)
}

final class EmptyPersonViewRouterImplementation: EmptyPersonViewRouter {

  private weak var emptyPersonViewController: EmptyPersonViewController?

  init(emptyPersonViewController: EmptyPersonViewController) {
    self.emptyPersonViewController = emptyPersonViewController
  }

  func presentAddPerson(addPersonPresenterDelegate: EditPersonPresenterDelegate?) {
    let configurator = AddPersonConfigurator(editPersonPresenterDelegate: addPersonPresenterDelegate)
    let addPersonViewController = EditPersonViewController(configurator: configurator)
    let navigationViewController = UINavigationController(rootViewController: addPersonViewController)
    emptyPersonViewController?.present(navigationViewController, animated: true)
  }
}
