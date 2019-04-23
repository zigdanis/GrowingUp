//
//  DatePickerView.swift
//  GrowingUp
//
//  Created by zigdanis on 21/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol DatePickerViewDelegate: class {
	func datePicker(picker: DatePickerView, selectedDate date: Date)
	func datePickerDidHide(picker: DatePickerView)
}

final class DatePickerView: UIView {

	weak var delegate: DatePickerViewDelegate?
	private let hoverView = UIView()
	private let paddingView = UIView()
	private let datePicker = UIDatePicker()
	private let toolbar = UIToolbar()
	private var toolbarTop: NSLayoutConstraint!

	init(mode: UIDatePicker.Mode) {
		super.init(frame: .zero)
		backgroundColor = .clear
		alpha = 0
		setupHoverView()
		setupPaddingView()
		setupDatePicker(with: mode)
		setupToolbar()
	}

	@available(iOS, unavailable, message: "Class does not intended to be created from xib")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Setup

	private func setupHoverView() {
		hoverView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.3)
		hoverView.translatesAutoresizingMaskIntoConstraints = false
		hoverView.alpha = 0
		addSubview(hoverView)
		let consts = [
			hoverView.leadingAnchor.constraint(equalTo: leadingAnchor),
			hoverView.topAnchor.constraint(equalTo: topAnchor),
			trailingAnchor.constraint(equalTo: hoverView.trailingAnchor),
			bottomAnchor.constraint(equalTo: hoverView.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)

		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
		hoverView.addGestureRecognizer(tapGesture)
	}

	private func setupPaddingView() {
		paddingView.backgroundColor = .white
		paddingView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(paddingView)
		var consts = [
			paddingView.leadingAnchor.constraint(equalTo: leadingAnchor),
			trailingAnchor.constraint(equalTo: paddingView.trailingAnchor)
		]
		let top = paddingView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
		let bottom = bottomAnchor.constraint(equalTo: paddingView.bottomAnchor)
		top.priority = .defaultHigh
		bottom.priority = .defaultHigh
		consts.append(top)
		consts.append(bottom)
		NSLayoutConstraint.activate(consts)
	}

	private func setupDatePicker(with mode: UIDatePicker.Mode) {
		datePicker.maximumDate = Date()
		datePicker.datePickerMode = mode
		datePicker.backgroundColor = .white
		datePicker.translatesAutoresizingMaskIntoConstraints = false
		addSubview(datePicker)
		let consts = [
			datePicker.leadingAnchor.constraint(equalTo: leadingAnchor),
			paddingView.topAnchor.constraint(equalTo: datePicker.bottomAnchor),
			trailingAnchor.constraint(equalTo: datePicker.trailingAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

	private func setupToolbar() {
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
		let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		toolbar.setItems([cancelButton, space, doneButton], animated: false)
		toolbar.translatesAutoresizingMaskIntoConstraints = false
		addSubview(toolbar)
		let consts = [
			toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
			trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
			datePicker.topAnchor.constraint(equalTo: toolbar.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
		toolbarTop = toolbar.topAnchor.constraint(equalTo: bottomAnchor)
		toolbarTop.isActive = true
	}

	// MARK: - Business Logic

	private func hidePicker() {
		toolbarTop.isActive = true
		UIView.animate(withDuration: 0.2, animations: {
			self.layoutSubviews()
			self.hoverView.alpha = 0
		}, completion: { _ in
			self.delegate?.datePickerDidHide(picker: self)
		})
	}

	func showPicker(with date: Date) {
		datePicker.date = date
		toolbarTop.isActive = false
		UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6, options: [], animations: {
			self.layoutSubviews()
			self.hoverView.alpha = 1
		}, completion: nil)
	}

	// MARK: - Actions

	@objc
	private func cancelTapped() {
		hidePicker()
	}

	@objc
	private func doneTapped() {
		delegate?.datePicker(picker: self, selectedDate: datePicker.date)
		hidePicker()
	}

}
