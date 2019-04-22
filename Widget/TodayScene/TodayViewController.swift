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

final class TodayViewController: UIViewController, NCWidgetProviding {

	private let identifier = "PersonTableViewCell"
	@IBOutlet weak var tableView: UITableView!
	private let presenter = TodayPresenterImplementation()

    override func viewDidLoad() {
        super.viewDidLoad()
		setupTableView()
		extensionContext?.widgetLargestAvailableDisplayMode = .expanded
    }

	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self
		let nib = UINib(nibName: identifier, bundle: nil)
		tableView.register(nib, forCellReuseIdentifier: identifier)
		tableView.estimatedRowHeight = 44
		tableView.tableFooterView = UIView()
	}

	func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
		switch activeDisplayMode {
		case .compact:
			presenter.maxRows = 1
			preferredContentSize = maxSize
		case .expanded:
			presenter.maxRows = 3
			preferredContentSize = CGSize(width: maxSize.width, height: 300)
		@unknown default:
			fatalError("We are not ready for the new DisplayMode")
		}
		tableView.reloadData()
	}

    // MARK: - Actions

    private func widgetTouched() {
        let url = URL(string: "growingup-app://")!
        extensionContext?.open(url, completionHandler: nil)
    }

}

extension TodayViewController: UITableViewDelegate, UITableViewDataSource {

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return preferredContentSize.height / CGFloat(presenter.numberOfPersons())
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return presenter.numberOfPersons()
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		return cell
	}
}
