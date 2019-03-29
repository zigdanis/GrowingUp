//
//  AddPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

protocol AddPersonView: ImagesCellViewDelegate {
    func updateAddButtonState(isEnabled enabled: Bool)
    func updateCancelButtonState(isEnabled enabled: Bool)
    func displayAddPersonError(title: String, message: String)
}

typealias APC = AddPersonViewController

final class AddPersonViewController: UIViewController, AddPersonView {

	static let imagePickerRow = 0
	static let nameFieldRow = 1
	static let dayPickerRow = 2
	static let timePickerRow = 3
	static let dateComponentsRows = 4...9

    var presenter: AddPersonPresenter!
    private let configurator: AddPersonConfigurator

    @IBOutlet weak var tableView: UITableView!
	private lazy var dayPickerView: DatePickerView = bdPickerView(for: .date)
	private lazy var timePickerView: DatePickerView = bdPickerView(for: .time)
	private lazy var wdImagePicker: WDImagePicker = generateWDImagePicker()

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
        setupTableView()
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }

    private func setupTableView() {
        tableView.dataSource = self
		tableView.delegate = self
        tableView.register(R.nib.textFieldTableVIewCell)
        tableView.register(R.nib.dateTableViewCell)
        tableView.register(R.nib.switchTableViewCell)
		tableView.register(R.nib.imagesTableViewCell)
		tableView.tableFooterView = UIView()
		tableView.keyboardDismissMode = .onDrag
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

	private func generateWDImagePicker() -> WDImagePicker {
		let size = CGSize(width: 320, height: 320)
		let picker = WDImagePicker(cropSize: size)
		picker.delegate = self
		return picker
	}

    // MARK: - Actions

	@objc internal func cancelTapped() {
        presenter.cancelButtonPressed()
		view.endEditing(true)
    }

    @objc private func doneTapped() {
        presenter.addButtonPressed()
		view.endEditing(true)
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

	func showDayPickerView() {
		dayPickerView.layoutIfNeeded()
		dayPickerView.alpha = 1
		dayPickerView.showPicker()
		view.endEditing(true)
	}

	func showTimePickerView() {
		timePickerView.layoutIfNeeded()
		timePickerView.alpha = 1
		timePickerView.showPicker()
		view.endEditing(true)
	}

	func showImagePicker() {
		let imagePicker = wdImagePicker.imagePickerController
		present(imagePicker, animated: true)
	}
}

extension AddPersonViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch indexPath.row {
		case APC.imagePickerRow:
			let identifier = R.reuseIdentifier.imagesTableViewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case APC.nameFieldRow:
			let identifier = R.reuseIdentifier.textFieldTableVIewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case APC.dayPickerRow, APC.timePickerRow:
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
		if indexPath.row == APC.nameFieldRow {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.becomeFirstResponder()
		} else if indexPath.row == APC.dayPickerRow {
			showDayPickerView()
		} else if indexPath.row == APC.timePickerRow {
			showTimePickerView()
		}
 	}
}

extension AddPersonViewController: DatePickerViewDelegate {

	func datePickerDidHide(picker: DatePickerView) {
		picker.alpha = 0
	}

	func datePicker(picker: DatePickerView, selectedDate date: Date) {
		if picker === dayPickerView {
			presenter.dateFor(row: APC.dayPickerRow, didUpdateTo: date)
		} else if picker === timePickerView {
			presenter.dateFor(row: APC.timePickerRow, didUpdateTo: date)
		}
		tableView.reloadData()
	}
}

extension AddPersonViewController: ImagesCellViewDelegate {

	func showAppPicImagePickerFor(row: Int) {
		print("Show Image picker for App Pic at row = \(row)")
		showImagePicker()
	}

	func showWidgetPicImagePickerFor(row: Int) {
		print("Show Image picker for Widget Pic at row = \(row)")
		showImagePicker()
	}
}

extension AddPersonViewController: WDImagePickerDelegate {

	func imagePicker(_ imagePicker: WDImagePicker, pickedImage: UIImage) {
		print("picked image with size = \(pickedImage.size)")
		imagePicker.imagePickerController.dismiss(animated: true)
	}

	func imagePickerDidCancel(_ imagePicker: WDImagePicker) {
		print("Cancel imagePicker")
		imagePicker.imagePickerController.dismiss(animated: true)
	}

}
