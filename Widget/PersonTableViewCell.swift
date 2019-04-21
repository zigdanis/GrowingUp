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

}
