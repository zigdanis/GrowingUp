//
//  PersonCell.swift
//  Widget
//
//  Created by zigdanis on 21/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

protocol PersonCellView {
	func displayName(name: String)
	func displayAge(age: String)
	func displayWidgetPic(pic: UIImage)
}

final class PersonTableViewCell: UITableViewCell, PersonCellView {
	@IBOutlet weak var ageLabel: UILabel!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var faceImage: UIImageView!

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

	func displayAge(age: String) {
		ageLabel.text = age
	}

	func displayWidgetPic(pic: UIImage) {
		faceImage.image = pic
	}
}
