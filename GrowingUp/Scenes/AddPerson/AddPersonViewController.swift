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

final class AddPersonViewController: UIViewController, AddPersonView {
    
    var presenter: AddPersonPresenter!
    private let configurator: AddPersonConfigurator
    
    @IBOutlet weak var appPicButton: ImagePickerButton!
    @IBOutlet weak var widgetPicButton: ImagePickerButton!
    @IBOutlet weak var appPicLabel: UILabel!
    @IBOutlet weak var widgetPicLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
	private lazy var datePickerView: DatePickerView = bdPickerView(for: .date)
	private lazy var timePickerView: DatePickerView = bdPickerView(for: .time)
    
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
		tableView.delegate = self
        tableView.register(R.nib.textFieldTableVIewCell)
        tableView.register(R.nib.dateTableViewCell)
        tableView.register(R.nib.switchTableViewCell)
    }
	
	private func bdPickerView(for mode: UIDatePicker.Mode) -> DatePickerView {
		let picker = DatePickerView(mode: mode)
		picker.delegate = self
		picker.translatesAutoresizingMaskIntoConstraints = false
		let parentView: UIView! = navigationController?.view ?? view
		parentView.addSubview(picker)
		let consts = [
			picker.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
			picker.topAnchor.constraint(equalTo: parentView.topAnchor),
			parentView.trailingAnchor.constraint(equalTo: picker.trailingAnchor),
			parentView.bottomAnchor.constraint(equalTo: picker.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
		return picker
	}
		
    // MARK: - Actions
    
	@objc internal func cancelTapped() {
        presenter.cancelButtonPressed()
		tableView.endEditing(true)
    }
    
    @objc private func doneTapped() {
        presenter.addButtonPressed()
		tableView.endEditing(true)
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
	
	// MARK: - Business Logic
	
	func showDatePickerView() {
		datePickerView.layoutIfNeeded()
		datePickerView.alpha = 1
		datePickerView.showPicker()
	}
	
	func showTimePickerView() {
		timePickerView.layoutIfNeeded()
		timePickerView.alpha = 1
		timePickerView.showPicker()
	}
}

extension AddPersonViewController: UITableViewDataSource, UITableViewDelegate {
    
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
            let identifier = R.reuseIdentifier.dateTableViewCell
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
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: false)
		if indexPath.row == 1 {
			showDatePickerView()
		} else if indexPath.row == 2 {
			showTimePickerView()
		}
 	}
}

extension AddPersonViewController: DatePickerViewDelegate {
	
	func datePickerDidHide(picker: DatePickerView) {
		picker.alpha = 0
	}
	
	func datePicker(picker: DatePickerView, selectedDate date: Date) {
		if picker === datePickerView {
			presenter.dateFor(row: 1, didUpdateTo: date)
		} else if picker === timePickerView {
			presenter.dateFor(row: 2, didUpdateTo: date)
		}
		tableView.reloadData()
	}
}
