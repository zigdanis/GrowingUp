//
//  RemoveButtonFooter.swift
//  GrowingUp
//
//  Created by zigdanis on 23/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol RemoveButtonDelegate: AnyObject {
	func removeTouched()
}

final class RemoveButtonFooter: UIView {

	weak var delegate: RemoveButtonDelegate?
	private let button = UIButton(type: .custom)

	init() {
		super.init(frame: .zero)
		commonInit()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		commonInit()
	}

	private func commonInit() {
		setupButton()

		button.translatesAutoresizingMaskIntoConstraints = false
		addSubview(button)
		let consts = [
			button.centerXAnchor.constraint(equalTo: centerXAnchor),
			button.topAnchor.constraint(equalTo: topAnchor, constant: 24),
			bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 24)
		]
		NSLayoutConstraint.activate(consts)
	}

	private func setupButton() {
		button.addTarget(self, action: #selector(removeTouched), for: .touchUpInside)
		button.setTitle(R.string.localizable.remove(), for: .normal)
		button.titleLabel?.font = .systemFont(ofSize: 24, weight: .light)
		button.setTitleColor(#colorLiteral(red: 1, green: 0.231372549, blue: 0.1882352941, alpha: 1), for: .normal)
		button.setTitleColor(#colorLiteral(red: 1, green: 0.231372549, blue: 0.1882352941, alpha: 0.5), for: .highlighted)
	}

	@objc
	private func removeTouched() {
		delegate?.removeTouched()
	}
}
