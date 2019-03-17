//
//  AddPersonViewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol AddPersonViewRouter {
    func dismiss()
}

class AddPersonViewRouterImplementation: AddPersonViewRouter {
    
    private weak var addPersonViewController: AddPersonViewController?
    
    init(addPersonViewController: AddPersonViewController) {
        self.addPersonViewController = addPersonViewController
    }
    
    func dismiss() {
        addPersonViewController?.dismiss(animated: true)
    }
}
