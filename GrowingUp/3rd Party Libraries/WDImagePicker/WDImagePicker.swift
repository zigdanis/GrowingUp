//
//  WDImagePicker.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

enum CropSize {
	case screen
	case circle
}

protocol WDImagePickerDelegate: class {
    func imagePicker(_ imagePicker: WDImagePicker, pickedImage: UIImage)
    func imagePickerDidCancel(_ imagePicker: WDImagePicker)
}

class WDImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, WDImageCropControllerDelegate {

	let imagePickerController: UIImagePickerController
	weak var delegate: WDImagePickerDelegate?
	private let cropSize: CropSize

	init(cropSize: CropSize) {
		self.cropSize = cropSize
		self.imagePickerController = UIImagePickerController()
		super.init()
		setupImagePickerController()
	}

	@available(iOS, unavailable, message: "Use init(cropSize:) instead")
	override init() {
		fatalError("Use init(cropSize:) instead")
    }

	private func setupImagePickerController() {
		imagePickerController.delegate = self
		imagePickerController.sourceType = .photoLibrary
	}

    private func hideController() {
        imagePickerController.dismiss(animated: true)
    }

	// MARK: - UIImagePickerController Delegate

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		guard let delegate = delegate else {
			return hideController()
		}
		delegate.imagePickerDidCancel(self)
    }

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
		guard let sourceImage = info[.originalImage] as? UIImage else {
			return hideController()
		}
		let cropController = WDImageCropViewController(sourceImage: sourceImage, cropSize: cropSize)
        cropController.delegate = self
        picker.pushViewController(cropController, animated: true)
    }

    func imageCropController(_ imageCropController: WDImageCropViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        delegate?.imagePicker(self, pickedImage: croppedImage)
    }

	func imageCropControllerFailedCroppingImage(_ imageCropController: WDImageCropViewController) {
		delegate?.imagePickerDidCancel(self)
	}
}
