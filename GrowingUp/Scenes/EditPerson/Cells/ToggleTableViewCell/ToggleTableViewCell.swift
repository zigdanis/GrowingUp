//
//  ToggleTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 28/06/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol ToggleCellView {
	func display(title: String)
	func display(isOn: Bool, animated: Bool)
	func setup(with presenter: ToggleCellPresenter?, forRow row: Int)
}

final class ToggleTableViewCell: UITableViewCell, ToggleCellView {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var toggle: UISwitch!
	private weak var presenter: ToggleCellPresenter?
	private var row: Int?

	override func awakeFromNib() {
		super.awakeFromNib()
		selectionStyle = .none
		toggle.addTarget(self, action: #selector(toggleDidChange(sender:)), for: .valueChanged)
	}

	// MARK: - ToggleCellView

	func display(title: String) {
		titleLabel.text = title
	}

	func display(isOn: Bool, animated: Bool) {
		toggle.setOn(isOn, animated: animated)
	}

	func setup(with presenter: ToggleCellPresenter?, forRow row: Int) {
		self.presenter = presenter
		self.row = row
	}

	// MARK: - Actions

	@objc
	private func toggleDidChange(sender: UISwitch) {
		guard let row = row else { return }
		presenter?.toggleValueFor(row: row, didChangeTo: sender.isOn)
	}

}
