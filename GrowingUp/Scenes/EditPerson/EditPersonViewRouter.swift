//
//  EditPersonViewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EditPersonViewRouter {
    func dismiss()
}

class EditPersonViewRouterImplementation: EditPersonViewRouter {

    private weak var addPersonViewController: EditPersonViewController?

    init(addPersonViewController: EditPersonViewController) {
        self.addPersonViewController = addPersonViewController
    }

    func dismiss() {
        addPersonViewController?.dismiss(animated: true)
    }
}
