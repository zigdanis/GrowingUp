//
//  ImagePickersTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 22/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

class ImagePickersTableViewCell: UITableViewCell {
	@IBOutlet weak var appPicButton: ImagePickerButton!
	@IBOutlet weak var widgetPicButton: ImagePickerButton!
	@IBOutlet weak var appPicLabel: UILabel!
	@IBOutlet weak var widgetPicLabel: UILabel!

	override func awakeFromNib() {
		super.awakeFromNib()
		selectionStyle = .none
		setupImagePickerViews()
	}

	private func setupImagePickerViews() {
		appPicLabel.text = R.string.localizable.appPic()
		widgetPicLabel.text = R.string.localizable.widgetPic()
	}
}
