//
//  ImagePickersTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 22/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol ImagesCellView: class {
	func display(appPic: PersonImage?)
	func display(widgetPic: PersonImage?)
	func setup(with delegate: ImagesCellViewDelegate, forRow row: Int)
}

protocol ImagesCellViewDelegate: class {
	func showAppPicImagePickerFor(row: Int)
	func showWidgetPicImagePickerFor(row: Int)
}

class ImagesTableViewCell: UITableViewCell, ImagesCellView {
	@IBOutlet weak var appPicButton: ImagePickerButton!
	@IBOutlet weak var widgetPicButton: ImagePickerButton!
	@IBOutlet weak var appPicLabel: UILabel!
	@IBOutlet weak var widgetPicLabel: UILabel!
	private weak var delegate: ImagesCellViewDelegate?
	private var row: Int?

	override func awakeFromNib() {
		super.awakeFromNib()
		selectionStyle = .none
		setupImagePickerViews()
		setupPickerButtons()
	}

	private func setupImagePickerViews() {
		appPicLabel.text = R.string.localizable.appPic()
		widgetPicLabel.text = R.string.localizable.widgetPic()
	}

	private func setupPickerButtons() {
		appPicButton.addTarget(self, action: #selector(appPicTouched), for: .touchUpInside)
		widgetPicButton.addTarget(self, action: #selector(widgetPicTouched), for: .touchUpInside)
	}

	// MARK: - ImagesCellView

	func display(appPic: PersonImage?) {
		guard let appPic = appPic else {
			appPicButton.drawImage(nil)
			return
		}
		if let uiImage = appPic.uiImage {
			appPicButton.drawImage(uiImage)
		} else {
			ImagesCache.loadImageFromDisk(image: appPic) { img in
				self.appPicButton.drawImage(img)
			}
		}
	}

	func display(widgetPic: PersonImage?) {
		guard let widgetPic = widgetPic else {
			widgetPicButton.drawImage(nil)
			return
		}
		if let uiImage = widgetPic.uiImage {
			widgetPicButton.drawImage(uiImage)
		} else {
			ImagesCache.loadImageFromDisk(image: widgetPic) { img in
				self.widgetPicButton.drawImage(img)
			}
		}
	}

	func setup(with delegate: ImagesCellViewDelegate, forRow row: Int) {
		self.delegate = delegate
		self.row = row
	}

	// MARK: - Actions

	@objc
	private func appPicTouched() {
		guard let row = row else { return }
		delegate?.showAppPicImagePickerFor(row: row)
	}

	@objc
	private func widgetPicTouched() {
		guard let row = row else { return }
		delegate?.showWidgetPicImagePickerFor(row: row)
	}
}
