//
//  EditPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

protocol EditPersonView: ImagesCellViewDelegate {
    func updateAddButtonState(isEnabled enabled: Bool)
    func updateCancelButtonState(isEnabled enabled: Bool)
    func displayAddPersonError(title: String, message: String)
	func displayScreenTitle(title: String)
}

typealias APC = EditPersonViewController

final class EditPersonViewController: UIViewController, EditPersonView {

	static let imagePickerRow = 0
	static let nameFieldRow = 1
	static let dayPickerRow = 2
	static let timePickerRow = 3
	static let dateComponentsRows = 4...9

    var presenter: EditPersonPresenter!
    private let configurator: EditPersonConfigurator

    @IBOutlet weak var tableView: UITableView!
	private lazy var dayPickerView: DatePickerView = bdPickerView(for: .date)
	private lazy var timePickerView: DatePickerView = bdPickerView(for: .time)
	private lazy var appPicImagePicker = WDImagePicker()
	private lazy var widgetPicImagePicker = WDImagePicker()

    init(configurator: EditPersonConfigurator) {
        self.configurator = configurator
        super.init(nibName: nil, bundle: nil)
    }

	@available(iOS, unavailable, message: "init(coder:) not implemented")
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

    // MARK: - Actions

	@objc
	internal func cancelTapped() {
        presenter.cancelButtonPressed()
		view.endEditing(true)
    }

    @objc
	private func doneTapped() {
        presenter.addButtonPressed()
		view.endEditing(true)
    }

    // MARK: - EditPersonView

    func updateAddButtonState(isEnabled enabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = enabled
    }

    func updateCancelButtonState(isEnabled enabled: Bool) {
        navigationItem.leftBarButtonItem?.isEnabled = enabled
    }

	func displayScreenTitle(title: String) {
		self.title = title
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
}

extension EditPersonViewController: UITableViewDataSource, UITableViewDelegate {

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

extension EditPersonViewController: DatePickerViewDelegate {

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

extension EditPersonViewController: ImagesCellViewDelegate {

	func showAppPicImagePickerFor(row: Int) {
		appPicImagePicker.delegate = self
		present(appPicImagePicker.imagePickerController, animated: true)
	}

	func showWidgetPicImagePickerFor(row: Int) {
		widgetPicImagePicker.delegate = self
		present(widgetPicImagePicker.imagePickerController, animated: true)
	}
}

extension EditPersonViewController: WDImagePickerDelegate {

	func imagePicker(_ imagePicker: WDImagePicker, pickedImage: UIImage) {
		if imagePicker === appPicImagePicker {
			presenter.appImagePicked(image: PersonImage(uiImage: pickedImage))
		} else if imagePicker === widgetPicImagePicker {
			presenter.widgetImagePicked(image: PersonImage(uiImage: pickedImage))
		}
		tableView.reloadData()
		imagePicker.imagePickerController.dismiss(animated: true)
	}

	func imagePickerDidCancel(_ imagePicker: WDImagePicker) {
		imagePicker.imagePickerController.dismiss(animated: true)
	}

}
