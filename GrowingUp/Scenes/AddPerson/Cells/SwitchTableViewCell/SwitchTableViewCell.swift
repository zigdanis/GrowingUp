//
//  SwitchTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol SwitchCellView {
    func display(title: String)
    func setSwitch(isOn: Bool)
	func setup(with presenter: SwitchCellPresenter, forRow row: Int)
}

final class SwitchTableViewCell: UITableViewCell, SwitchCellView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueSwitch: UISwitch!
	private weak var presenter: SwitchCellPresenter?
	private var row: Int?

	override func awakeFromNib() {
		super.awakeFromNib()
		valueSwitch.addTarget(self, action: #selector(switchValueChanged(sender:)), for: .valueChanged)
	}

    func display(title: String) {
        titleLabel.text = title
    }

    func setSwitch(isOn: Bool) {
        valueSwitch.setOn(isOn, animated: false)
    }

	func setup(with presenter: SwitchCellPresenter, forRow row: Int) {
		self.presenter = presenter
		self.row = row
	}

	@objc
	private func switchValueChanged(sender: UISwitch) {
		guard let row = row else { return }
		guard let presenter = presenter else { return }
		presenter.valueFor(row: row, didChangeTo: sender.isOn)
	}
}
