//
//  ImagePickersTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 22/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit
import Core

protocol ImagesCellView: class {
	func display(appPic: PersonImage?)
	func display(widgetPic: PersonImage?)
	func setup(with delegate: ImagesCellViewDelegate, forRow row: Int)
}

protocol ImagesCellViewDelegate: class {
	func showAppPicImagePickerFor(row: Int)
	func showWidgetPicImagePickerFor(row: Int)
}

final class ImagesTableViewCell: UITableViewCell, ImagesCellView {
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
		appPicLabel.text = R.string.localizable.mainPic()
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
			ImagesCache.loadImageFromDiskOrMemory(image: appPic) { result in
				switch result {
				case .success(let img):
					self.appPicButton.drawImage(img)
				case .failure(let error):
					Logging.logError(error)
				}
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
			ImagesCache.loadImageFromDiskOrMemory(image: widgetPic) { result in
				switch result {
				case .success(let img):
					self.widgetPicButton.drawImage(img)
				case .failure(let error):
					Logging.logError(error)
				}
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
