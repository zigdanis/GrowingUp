//
//  AddPersonViewController.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

protocol AddPersonView: class {
    func updateAddButtonState(isEnabled enabled: Bool)
    func updateCancelButtonState(isEnabled enabled: Bool)
    func displayAddPersonError(title: String, message: String)
}

class AddPersonViewController: UIViewController, AddPersonView {
    
    var presenter: AddPersonPresenter!
    let configurator: AddPersonConfigurator
    
    init(configurator: AddPersonConfigurator) {
        self.configurator = configurator
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurator.configure(addPersonViewController: self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    func updateAddButtonState(isEnabled enabled: Bool) {

    }
    
    func updateCancelButtonState(isEnabled enabled: Bool) {
        
    }
    
    func displayAddPersonError(title: String, message: String) {
        
    }
    
    
}
