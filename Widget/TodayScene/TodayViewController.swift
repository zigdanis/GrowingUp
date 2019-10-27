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
	func reloadTableData()
}

final class TodayViewController: UIViewController, NCWidgetProviding, TodayView {

	private let identifier = "PersonTableViewCell"
	private var presentingRowsLimit = 1
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var addPersonButton: UIButton!
	private let presenter = TodayPresenterImplementation()
	private var constrainedNumberOfPersons: Int {
		min(presentingRowsLimit, presenter.numberOfPersons())
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		Logging.logMessage("Open up Today Widget")
		presenter.view = self
		setupTableView()
		setupAddPersonButton()
		presenter.loadPersons()
		tunePresenting()
		reloadTableData()
    }

	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self
		let nib = UINib(nibName: identifier, bundle: nil)
		tableView.register(nib, forCellReuseIdentifier: identifier)
		tableView.estimatedRowHeight = 44
		tableView.tableFooterView = UIView()
	}

	private func setupAddPersonButton() {
		guard let bundle = Bundle(identifier: Constants.bundleIdentifier) else { return }
		let ttl = NSLocalizedString("Add person", bundle: bundle, comment: "")
		addPersonButton.setTitle(ttl, for: .normal)
	}

	private func tunePresenting(forMode mode: NCWidgetDisplayMode? = nil, maxSize: CGSize? = nil) {
		guard let mode = mode ?? extensionContext?.widgetActiveDisplayMode else { return }
		guard let maxSize = maxSize ?? extensionContext?.widgetMaximumSize(for: mode) else { return }
		switch mode {
		case .compact:
			presentingRowsLimit = 1
			preferredContentSize = maxSize
		case .expanded:
			presentingRowsLimit = rowsLimit
			let height = CGFloat(presenter.numberOfPersons() * 100)
			preferredContentSize = CGSize(width: maxSize.width, height: height)
		@unknown default:
			fatalError("We are not ready for the new DisplayMode")
		}
	}

	private func setupMaxWidgetSize() {
		if presenter.numberOfPersons() > 1 {
			extensionContext?.widgetLargestAvailableDisplayMode = .expanded
		} else {
			extensionContext?.widgetLargestAvailableDisplayMode = .compact
		}
	}

	// MARK: - TodayView

	func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
		tunePresenting(forMode: activeDisplayMode, maxSize: maxSize)
		reloadTableData()
	}

    // MARK: - Actions

	func reloadTableData() {
		setupMaxWidgetSize()
		tableView.reloadData()
		let isHidden = presenter.numberOfPersons() == 0
		tableView.isHidden = isHidden
		addPersonButton.isHidden = !isHidden
	}

	private func widgetTouched(atIndex index: Int) {
		let str = "growingup-app://?\(Constants.widgetPersonIndexKey)=\(index)"
		let url = URL(string: str)!
        extensionContext?.open(url, completionHandler: nil)
    }

	@IBAction func addPersonTouched() {
		Logging.logMessage("User pressed Add Person from within Widget")
		widgetTouched(atIndex: 0)
	}
}

extension TodayViewController: UITableViewDelegate, UITableViewDataSource {

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		var persons = CGFloat(constrainedNumberOfPersons)
		persons = max(1, persons)
		return preferredContentSize.height / persons
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return constrainedNumberOfPersons
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		guard let personCell = cell as? PersonCellView else {
			fatalError("Expected to dequeue PersonCellView")
		}
		presenter.configure(cell: personCell, atIndex: indexPath.row)
		return cell
	}

	func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		guard let personCell = cell as? PersonCellView else {
			fatalError("Expected to dequeue PersonCellView")
		}
		personCell.cancelTimer()
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		widgetTouched(atIndex: indexPath.row)
	}
}
