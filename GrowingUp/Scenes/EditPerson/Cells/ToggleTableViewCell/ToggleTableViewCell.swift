//
//  ToggleTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 28/06/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import UIKit

protocol ToggleCellView {
	func display(title: String)
	func display(isOn: Bool, animated: Bool)
	func setup(with delegate: ToggleCellDelegate?, forRow row: Int)
}

@MainActor
protocol ToggleCellDelegate: AnyObject {
	func toggle(toggle: ToggleCellView, didChangeStateForRow row: Int, to state: Bool)
}

final class ToggleTableViewCell: UITableViewCell, ToggleCellView {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var toggle: UISwitch!
	private weak var delegate: ToggleCellDelegate?
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

	func setup(with delegate: ToggleCellDelegate?, forRow row: Int) {
		self.delegate = delegate
		self.row = row
	}

	// MARK: - Actions

	@objc
	private func toggleDidChange(sender: UISwitch) {
		guard let row = row else { return }
		delegate?.toggle(toggle: self, didChangeStateForRow: row, to: sender.isOn)
	}

}
