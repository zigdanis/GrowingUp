//
//  AddPersonViewController.swift
//  GrowingUp
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

class AddPersonViewController: UIViewController, AddPersonView, UITableViewDataSource {
    
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
        setupTableView()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }
    
    private func setupImagePickerViews() {
        appPicLabel.text = R.string.localizable.appPic()
        widgetPicLabel.text = R.string.localizable.widgetPic()
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(R.nib.textFieldTableVIewCell)
        tableView.register(R.nib.labelTableViewCell)
        tableView.register(R.nib.switchTableViewCell)
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        presenter.cancelButtonPressed()
    }
    
    @objc private func doneTapped() {
//        presenter.addButtonPressed(parameters: <#T##AddPersonParameters#>)
    }
    
    // MARK: - AddPersonView
    
    func updateAddButtonState(isEnabled enabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = enabled
    }
    
    func updateCancelButtonState(isEnabled enabled: Bool) {
        navigationItem.leftBarButtonItem?.isEnabled = enabled
    }
    
    func displayAddPersonError(title: String, message: String) {
        showAlert(title: title, message: message)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 9
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let identifier = R.reuseIdentifier.textFieldTableVIewCell
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
            presenter.configure(cell: cell, forRow: indexPath.row)
            return cell
        case 1...2:
            let identifier = R.reuseIdentifier.labelTableViewCell
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
            presenter.configure(cell: cell, forRow: indexPath.row)
            return cell
        default:
            let identifier = R.reuseIdentifier.switchTableViewCell
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
            presenter.configure(cell: cell, forRow: indexPath.row)
            return cell
        }
        
    }
    
    
}
