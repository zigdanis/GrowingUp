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
    private let configurator: AddPersonConfigurator
    
    @IBOutlet weak var appPicButton: ImagePickerButton!
    @IBOutlet weak var widgetPicButton: ImagePickerButton!
    @IBOutlet weak var appPicLabel: UILabel!
    @IBOutlet weak var widgetPicLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    init(configurator: AddPersonConfigurator) {
        self.configurator = configurator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurator.configure(addPersonViewController: self)
        setupNavigationBar()
        setupImagePickerViews()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }
    
    private func setupImagePickerViews() {
        appPicLabel.text = NSLocalizedString("app pic", comment: "text on label under app pic rounded button")
        widgetPicLabel.text = NSLocalizedString("widget pic", comment: "text on label under widget pic rounded button")
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        presenter.cancelButtonPressed()
    }
    
    @objc private func doneTapped() {
//        presenter.addButtonPressed(parameters: <#T##AddPersonParameters#>)
    }
    
    func updateAddButtonState(isEnabled enabled: Bool) {

    }
    
    func updateCancelButtonState(isEnabled enabled: Bool) {
        
    }
    
    func displayAddPersonError(title: String, message: String) {
        
    }
    
    
}
