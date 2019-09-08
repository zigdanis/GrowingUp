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
	func display(isOn: Bool)
	func setup(with delegate: ToggleCellViewDelegate?, forRow row: Int)
}

protocol ToggleCellViewDelegate: class {
	func toggleFor(row: Int)
}

final class ToggleTableViewCell: UITableViewCell, ToggleCellView {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var toggle: UISwitch!
	private weak var delegate: ToggleCellViewDelegate?
	private var row: Int?

	override func awakeFromNib() {
		super.awakeFromNib()
		selectionStyle = .none
	}

	// MARK: - ToggleCellView

	func display(title: String) {
		titleLabel.text = title
	}

	func display(isOn: Bool) {
		toggle.isOn = isOn
	}

	func setup(with delegate: ToggleCellViewDelegate?, forRow row: Int) {
		self.delegate = delegate
		self.row = row
	}

}
