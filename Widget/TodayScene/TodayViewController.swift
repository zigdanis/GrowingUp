//
//  TodayViewController.swift
//  Widget
//
//  Created by zigdanis on 15/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit
import NotificationCenter
import Core

let rowsLimit = 3

protocol TodayView: class {
	func updateContent()
}

final class TodayViewController: UIViewController, NCWidgetProviding, TodayView {

	private let identifier = "PersonTableViewCell"
	private var presentingRowsLimit = 1
	@IBOutlet weak var stackView: UIStackView!
	@IBOutlet weak var addPersonButton: UIButton!
	private let presenter = TodayPresenterImplementation()
	private var constrainedNumberOfPersons: Int {
		min(presentingRowsLimit, presenter.numberOfPersons)
	}
	private var prevActiveMode: NCWidgetDisplayMode?

	func dprint(function: String = #function) {
		print("✍️ \(function), mode = \(extensionContext!.widgetActiveDisplayMode.rawValue)")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		Logging.logMessage("Open up Today Widget")
		presenter.view = self
		setupStackView()
		setupAddPersonButton()
		presenter.loadPersons()
//		configureRowsLimitnForCurrentDisplayMode()
//		updateContent()
		updateMaxWidgetSize()
		stackView.backgroundColor = .yellow
		view.backgroundColor = .blue
	}

	private func setupStackView() {
		dprint()
		stackView.axis = .vertical
		stackView.distribution = .fillEqually
		stackView.alignment = .fill
		for _ in 0..<rowsLimit {
			let view = PersonViewPanel()
			view.isHidden = true
			stackView.addArrangedSubview(view)
		}
	}

	private func setupAddPersonButton() {
		dprint()
		guard let bundle = Bundle(identifier: Constants.bundleIdentifier) else { return }
		let ttl = NSLocalizedString("Add person", bundle: bundle, comment: "")
		addPersonButton.setTitle(ttl, for: .normal)
	}

	private func configureRowsLimitnForCurrentDisplayMode() {
		dprint()
		guard let mode = extensionContext?.widgetActiveDisplayMode else { return }
		switch mode {
		case .compact:
			presentingRowsLimit = 1
		case .expanded:
			presentingRowsLimit = rowsLimit
		@unknown default:
			fatalError("We are not ready for the new DisplayMode")
		}
	}

	private func updateMaxWidgetSize() {
		dprint()
		if presenter.numberOfPersons > 1 {
			extensionContext?.widgetLargestAvailableDisplayMode = .expanded
		} else {
			extensionContext?.widgetLargestAvailableDisplayMode = .compact
		}
	}

	private func updateStackViewItems() {
		dprint()
		for (index, view) in stackView.arrangedSubviews.enumerated() {
			let isHidden = index >= constrainedNumberOfPersons
			view.isHidden = isHidden
			guard !isHidden else { continue }
			guard let panel = view as? PersonViewPanel else { continue }
			presenter.configure(panel: panel, atIndex: index)
			panel.layoutIfNeeded()
		}

		let isHidden = presenter.numberOfPersons == 0
		stackView.isHidden = isHidden
		addPersonButton.isHidden = !isHidden
		stackView.layoutIfNeeded()
	}

	// MARK: - TodayView

	func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
		dprint()
		configureRowsLimitnForCurrentDisplayMode()
//		updateContent()

		UIView.animate(withDuration: 0.2) {
			self.updateStackViewItems()
		}
		prevActiveMode = activeDisplayMode
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		dprint()
		print("view will transition to size = \(size)")
		updateStackViewItems()
		coordinator.animate(alongsideTransition: { context in
			self.stackView.layoutIfNeeded()
		}, completion: nil)
	}

    // MARK: - Actions

	func updateContent() {
		dprint()
		updateMaxWidgetSize()
		updateStackViewItems()
	}

	private func widgetTouched(atIndex index: Int) {
		let str = "growingup-app://?\(Constants.widgetPersonIndexKey)=\(index)"
		let url = URL(string: str)!
        extensionContext?.open(url, completionHandler: nil)
    }

	@IBAction func addPersonTouched() {
		Logging.logMessage("User pressed Add Person from within Widget")
		let str = "growingup-app://add-person"
		let url = URL(string: str)!
		extensionContext?.open(url, completionHandler: nil)
	}
}

//extension TodayViewController: UITableViewDelegate, UITableViewDataSource {
//
//	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//		var persons = CGFloat(constrainedNumberOfPersons)
//		persons = max(1, persons)
//		return preferredContentSize.height / persons
//	}
//
//	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		return constrainedNumberOfPersons
//	}
//
//	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
//		guard let personCell = cell as? PersonCellView else {
//			fatalError("Expected to dequeue PersonCellView")
//		}
//		presenter.configure(cell: personCell, atIndex: indexPath.row)
//		return cell
//	}
//
//	func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//		guard let personCell = cell as? PersonCellView else {
//			fatalError("Expected to dequeue PersonCellView")
//		}
//		personCell.cancelTimer()
//	}
//
//	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//		tableView.deselectRow(at: indexPath, animated: true)
//		widgetTouched(atIndex: indexPath.row)
//	}
//}
