//
//  TextFieldTableVIewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol TextFieldCellView: AnyObject {
	func display(title: String)
	func display(value: String)
	func display(placeholder: String)
	func setup(with presenter: TextFieldCellPresenter, observer: TextFieldObserver?, forRow row: Int)
}

protocol TextFieldObserver: AnyObject {
	func textDidChange(forView: TextFieldCellView, text: String)
}

final class TextFieldTableViewCell: UITableViewCell, TextFieldCellView {

	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var valueField: UITextField!
	private weak var presenter: TextFieldCellPresenter?
	private weak var observer: TextFieldObserver?
	private var row: Int?

	override func awakeFromNib() {
		super.awakeFromNib()
		valueField.delegate = self
		valueField.addTarget(self, action: #selector(textDidChange(sender:)), for: .editingChanged)
		configureInputTraits()
	}

	override func becomeFirstResponder() -> Bool {
		// Forward focus to the text field only. Letting the cell itself become first
		// responder used to let the system route stray characters (e.g. a phantom "A")
		// into the field, so we no longer call super.
		return valueField.becomeFirstResponder()
	}

	private func configureInputTraits() {
		valueField.autocapitalizationType = .words
		valueField.autocorrectionType = .no
		valueField.spellCheckingType = .no
		valueField.smartInsertDeleteType = .no
		valueField.smartDashesType = .no
		valueField.smartQuotesType = .no
		// Names entered here are arbitrary (often children), not the device owner, so
		// Contacts AutoFill only inserts noise. Disabling it removes the source of the
		// auto-inserted character.
		valueField.textContentType = .none
	}

	// MARK: - TextFieldCellView

	func display(title: String) {
		titleLabel.text = title
	}

	func display(placeholder: String) {
		valueField.placeholder = placeholder
	}

	func display(value: String) {
		valueField.text = value
	}

	func setup(with presenter: TextFieldCellPresenter, observer: TextFieldObserver?, forRow row: Int) {
		self.presenter = presenter
		self.observer = observer
		self.row = row
	}

	// MARK: - Actions

	@objc
	private func textDidChange(sender: UITextField) {
		guard let row = row else { return }
		guard let presenter = presenter else { return }
		guard let value = sender.text else { return }
		presenter.valueFor(row: row, didChangeTo: value)
	}

}

extension TextFieldTableViewCell: UITextFieldDelegate {

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String)
		-> Bool
	{
		guard let text = textField.text else { return true }
		guard let textRange = Range(range, in: text) else { return true }
		let updatedText = text.replacingCharacters(in: textRange, with: string)
		observer?.textDidChange(forView: self, text: updatedText)
		return true
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
