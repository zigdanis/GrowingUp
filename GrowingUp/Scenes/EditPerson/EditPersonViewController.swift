//
//  EditPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit
import Core

enum BarButtonItemStyle {
	case cancel
	case done
	case save
}

protocol EditPersonView: ImagesCellViewDelegate {
    func updateBarButtonsState(isEnabled enabled: Bool)
    func displayEditPersonError(title: String, message: String)
	func displayScreenTitle(title: String)
	func displayBarButton(with style: BarButtonItemStyle)
	func reloadData()
}

typealias EPC = EditPersonViewController

final class EditPersonViewController: UIViewController, EditPersonView {

	// Visible table rows.
	static let imagePickerRow = 0
	static let nameFieldRow = 1
	static let birthdayRow = 2
	static let addToWidgetRow = 3

	// Logical storage keys for the combined birthday. The picker is a single control,
	// but the day and time are still stored (and persisted) separately, so a tap on the
	// combined picker writes the same date into both of these slots.
	static let dayPickerRow = 10
	static let timePickerRow = 11

    var presenter: EditPersonPresenter!
    private let configurator: EditPersonConfigurator

    @IBOutlet weak var tableView: UITableView!
	private lazy var appPicImagePicker = WDImagePicker(cropSize: .screen)
	private lazy var widgetPicImagePicker = WDImagePicker(cropSize: .circle)

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
        configurator.configure(editPersonViewController: self)
        setupTableView()
		setupTableFooter()
		presenter.viewDidLoad()
    }

    private func setupTableView() {
        tableView.dataSource = self
		tableView.delegate = self
        tableView.register(R.nib.textFieldTableVIewCell)
        tableView.register(R.nib.dateTableViewCell)
		tableView.register(R.nib.imagesTableViewCell)
		tableView.register(R.nib.toggleTableViewCell)
		tableView.keyboardDismissMode = .onDrag
    }

	private func setupTableFooter() {
		if presenter.shouldShowRemoveButton() {
			let rect = CGRect(x: 0, y: 0, width: 320, height: 66)
			let footer = RemoveButtonFooter(frame: rect)
			footer.delegate = self
			tableView.tableFooterView = footer
		} else {
			tableView.tableFooterView = UIView()
		}
	}

    // MARK: - Actions

	@objc
	internal func cancelTapped() {
        presenter.leftBarButtonPressed()
		view.endEditing(true)
    }

    @objc
	private func addTapped() {
        presenter.rightBarButtonPressed()
		view.endEditing(true)
    }

	@objc
	private func saveTapped() {
		presenter.rightBarButtonPressed()
		view.endEditing(true)
	}

    // MARK: - EditPersonView

    func updateBarButtonsState(isEnabled enabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = enabled
		navigationItem.leftBarButtonItem?.isEnabled = enabled
    }

	func displayScreenTitle(title: String) {
		self.title = title
	}

	func displayEditPersonError(title: String, message: String) {
        showAlert(title: title, message: message)
    }

	func displayBarButton(with style: BarButtonItemStyle) {
		switch style {
		case .cancel:
			navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
		case .done:
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(addTapped))
		case .save:
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		}
	}

	func reloadData() {
		tableView.reloadData()
	}
}

extension EditPersonViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch indexPath.row {
		case EPC.imagePickerRow:
			let identifier = R.reuseIdentifier.imagesTableViewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.nameFieldRow:
			let identifier = R.reuseIdentifier.textFieldTableVIewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.birthdayRow:
			let identifier = R.reuseIdentifier.dateTableViewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.addToWidgetRow:
			let identifier = R.reuseIdentifier.toggleTableViewCell
			let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)!
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		default:
			fatalError("This indexPath is not supported")
		}
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: false)
		if indexPath.row == EPC.nameFieldRow {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.becomeFirstResponder()
		}
 	}
}

extension EditPersonViewController: ImagesCellViewDelegate {

	func showAppPicImagePickerFor(row: Int) {
		view.endEditing(true)
		appPicImagePicker.delegate = self
		appPicImagePicker.present(from: self)
	}

	func showWidgetPicImagePickerFor(row: Int) {
		view.endEditing(true)
		widgetPicImagePicker.delegate = self
		widgetPicImagePicker.present(from: self)
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
	}

	func imagePickerDidCancel(_ imagePicker: WDImagePicker) {}
}

extension EditPersonViewController: RemoveButtonDelegate {
	func removeTouched() {
		presenter.removePersonPressed()
	}
}
