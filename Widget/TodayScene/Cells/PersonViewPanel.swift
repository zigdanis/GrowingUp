//
//  PersonCell.swift
//  Widget
//
//  Created by zigdanis on 21/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit
import Core

extension NSLayoutAnchor {
	@objc
	func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant: CGFloat, priority: UILayoutPriority) -> NSLayoutConstraint {
		let const = constraint(equalTo: anchor, constant: constant)
		const.priority = priority
		return const
	}
}

protocol PersonView {
	func displayName(name: String)
	func displayAge(for person: Person)
	func displayWidgetPic(pic: UIImage?)
	func cancelTimer()
}

final class PersonViewPanel: UIView, PersonView {

	let ageLabel = UILabel()
	let nameLabel = UILabel()
	let faceImage = UIImageView()
	private var timer: Timer?

	init() {
		super.init(frame: .zero)
		setupFaceImage()
		setupNameLabel()
//		setupAgeLabel()
		clipsToBounds = false
		backgroundColor = .green
		clipsToBounds = false
	}

	@available(iOS, unavailable, message: "Use init without params")
	override init(frame: CGRect) {
		fatalError("Not implemented")
	}

	@available(iOS, unavailable, message: "Use init without params")
	required init?(coder: NSCoder) {
		fatalError("Not implemented")
	}

	private func setupFaceImage() {
		faceImage.image = #imageLiteral(resourceName: "face")
		faceImage.contentMode = .scaleAspectFill
		faceImage.frame = CGRect(x: 16, y: 16, width: 60, height: 60)
		faceImage.layer.cornerRadius = faceImage.bounds.width / 2
		faceImage.translatesAutoresizingMaskIntoConstraints = false
		addSubview(faceImage)
		let consts = [
			faceImage.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			faceImage.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			faceImage.widthAnchor.constraint(equalToConstant: 60),
			faceImage.heightAnchor.constraint(equalToConstant: 60)
		]
		NSLayoutConstraint.activate(consts)
	}

	private func setupNameLabel() {
		nameLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
		nameLabel.adjustsFontForContentSizeCategory = true
		nameLabel.translatesAutoresizingMaskIntoConstraints = false
		addSubview(nameLabel)
		let consts = [
			nameLabel.centerXAnchor.constraint(equalTo: faceImage.centerXAnchor, constant: 0, priority: .defaultLow),
			nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
			trailingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 4),
			nameLabel.topAnchor.constraint(equalTo: faceImage.bottomAnchor, constant: 2),
			nameLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
			bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
		]
		NSLayoutConstraint.activate(consts)
		nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
	}

	private func setupAgeLabel() {
		ageLabel.translatesAutoresizingMaskIntoConstraints = false
		ageLabel.font = UIFont.preferredFont(forTextStyle: .body)
		ageLabel.adjustsFontForContentSizeCategory = true
		ageLabel.numberOfLines = 0
		addSubview(ageLabel)
		let consts = [
			ageLabel.leadingAnchor.constraint(equalTo: faceImage.trailingAnchor, constant: 10),
			trailingAnchor.constraint(equalTo: ageLabel.trailingAnchor, constant: 10),
			ageLabel.centerYAnchor.constraint(equalTo: faceImage.centerYAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}

	// MARK: - PersonCellView

	func displayName(name: String) {
		nameLabel.text = name
	}

	func displayAge(for person: Person) {
		setupCurrentAge(for: person)
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			self?.setupCurrentAge(for: person)
		}
	}

	func displayWidgetPic(pic: UIImage?) {
		faceImage.image = pic ?? #imageLiteral(resourceName: "face")
	}

	func cancelTimer() {
		timer?.invalidate()
	}

	private func setupCurrentAge(for person: Person) {
		let components = person.dateComponents
		let age = AgeCalculator.ageString(for: components)
		ageLabel.text = age
	}

}
