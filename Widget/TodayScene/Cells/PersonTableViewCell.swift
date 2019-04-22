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

protocol PersonCellView {
	func displayName(name: String)
	func displayAge(for person: Person)
	func displayWidgetPic(pic: UIImage?)
	func cancelTimer()
}

final class PersonTableViewCell: UITableViewCell, PersonCellView {
	@IBOutlet weak var ageLabel: UILabel!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var faceImage: UIImageView!
	private var timer: Timer?

	override func awakeFromNib() {
		super.awakeFromNib()
		setupFaceImage()
	}

	private func setupFaceImage() {
		faceImage.layer.cornerRadius = faceImage.bounds.width / 2
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
		faceImage.image = pic
	}

	func cancelTimer() {
		timer?.invalidate()
	}

	private func setupCurrentAge(for person: Person) {
		let components = person.dateComponents
		let age = AgeCalculator.ageString(for: components)
		print("setup current age to \(age)")
		ageLabel.text = age
	}

}
