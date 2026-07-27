//
//  EditPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Core
import Foundation
import SwiftUI
import UIKit

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

	// Reuse identifiers for the table cells, matching each cell's XIB file name.
	private enum CellID {
		static let textField = "TextFieldTableVIewCell"
		static let date = "DateTableViewCell"
		static let images = "ImagesTableViewCell"
		static let toggle = "ToggleTableViewCell"
	}

	var presenter: EditPersonPresenter!
	private let configurator: EditPersonConfigurator

	@IBOutlet weak var tableView: UITableView!

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
		tableView.register(UINib(nibName: CellID.textField, bundle: nil), forCellReuseIdentifier: CellID.textField)
		tableView.register(UINib(nibName: CellID.date, bundle: nil), forCellReuseIdentifier: CellID.date)
		tableView.register(UINib(nibName: CellID.images, bundle: nil), forCellReuseIdentifier: CellID.images)
		tableView.register(UINib(nibName: CellID.toggle, bundle: nil), forCellReuseIdentifier: CellID.toggle)
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
			navigationItem.leftBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
		case .done:
			navigationItem.rightBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .done, target: self, action: #selector(addTapped))
		case .save:
			navigationItem.rightBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
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
			let cell: ImagesTableViewCell = dequeue(CellID.images, at: indexPath)
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.nameFieldRow:
			let cell: TextFieldTableViewCell = dequeue(CellID.textField, at: indexPath)
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.birthdayRow:
			let cell: DateTableViewCell = dequeue(CellID.date, at: indexPath)
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		case EPC.addToWidgetRow:
			let cell: ToggleTableViewCell = dequeue(CellID.toggle, at: indexPath)
			presenter.configure(cell: cell, forRow: indexPath.row)
			return cell
		default:
			fatalError("This indexPath is not supported")
		}
	}

	private func dequeue<Cell: UITableViewCell>(_ identifier: String, at indexPath: IndexPath) -> Cell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? Cell else {
			fatalError("Could not dequeue cell with identifier \(identifier)")
		}
		return cell
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

	func showAppPicImagePickerFor(row: Int, source: ImageCaptureSource) {
		presentImageFlow(source: source, cropShape: .rectangle) { [weak self] image in
			self?.presenter.appImagePicked(image: PersonImage(uiImage: image))
			self?.tableView.reloadData()
		}
	}

	func showWidgetPicImagePickerFor(row: Int, source: ImageCaptureSource) {
		presentImageFlow(source: source, cropShape: .circle) { [weak self] image in
			self?.presenter.widgetImagePicked(image: PersonImage(uiImage: image))
			self?.tableView.reloadData()
		}
	}

	func removeAppPic(forRow row: Int) {
		presenter.removeAppImage()
		tableView.reloadData()
	}

	func removeWidgetPic(forRow row: Int) {
		presenter.removeWidgetImage()
		tableView.reloadData()
	}

	private func presentImageFlow(
		source: ImageCaptureSource,
		cropShape: CropShape,
		onPicked: @escaping (UIImage) -> Void
	) {
		view.endEditing(true)
		let flow = ImageCaptureFlowView(
			source: source,
			cropShape: cropShape,
			onComplete: { [weak self] image in
				self?.dismiss(animated: true) { onPicked(image) }
			},
			onCancel: { [weak self] in
				self?.dismiss(animated: true)
			}
		)
		let host = UIHostingController(rootView: flow)
		host.modalPresentationStyle = .pageSheet
		if let sheet = host.sheetPresentationController {
			// Keep the holder fixed while the photo grid scrolls inside it.
			let cardId = UISheetPresentationController.Detent.Identifier("card")
			sheet.detents = [.custom(identifier: cardId) { context in 0.62 * context.maximumDetentValue }]
			sheet.selectedDetentIdentifier = cardId
			sheet.prefersGrabberVisible = false
			sheet.preferredCornerRadius = 20
		}
		present(host, animated: true)
	}
}

extension EditPersonViewController: RemoveButtonDelegate {
	func removeTouched() {
		presenter.removePersonPressed()
	}
}
