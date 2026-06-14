//
//  WDImagePicker.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit
import PhotosUI

enum CropSize {
	case screen
	case circle
}

protocol WDImagePickerDelegate: AnyObject {
    func imagePicker(_ imagePicker: WDImagePicker, pickedImage: UIImage)
    func imagePickerDidCancel(_ imagePicker: WDImagePicker)
}

final class WDImagePicker: NSObject {

	weak var delegate: WDImagePickerDelegate?
	private let cropSize: CropSize
	private weak var presentingController: UIViewController?

	init(cropSize: CropSize) {
		self.cropSize = cropSize
		super.init()
	}

	/// Presents the modern Photos picker. After a photo is chosen the cropping screen
	/// is presented on top, and the cropped result is reported through `delegate`.
	func present(from viewController: UIViewController) {
		presentingController = viewController
		var configuration = PHPickerConfiguration()
		configuration.filter = .images
		configuration.selectionLimit = 1
		configuration.preferredAssetRepresentationMode = .current
		let picker = PHPickerViewController(configuration: configuration)
		picker.delegate = self
		viewController.present(picker, animated: true)
	}

	private func presentCropController(for image: UIImage) {
		let cropController = WDImageCropViewController(sourceImage: image, cropSize: cropSize)
		cropController.delegate = self
		let navigation = UINavigationController(rootViewController: cropController)
		navigation.modalPresentationStyle = .fullScreen
		presentingController?.present(navigation, animated: true)
	}
}

extension WDImagePicker: PHPickerViewControllerDelegate {

	func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
		guard let provider = results.first?.itemProvider,
			  provider.canLoadObject(ofClass: UIImage.self) else {
			picker.dismiss(animated: true) { self.delegate?.imagePickerDidCancel(self) }
			return
		}
		provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
			DispatchQueue.main.async {
				guard let self = self else { return }
				picker.dismiss(animated: true) {
					guard let image = object as? UIImage else {
						self.delegate?.imagePickerDidCancel(self)
						return
					}
					self.presentCropController(for: image)
				}
			}
		}
	}
}

extension WDImagePicker: WDImageCropControllerDelegate {

	func imageCropController(_ imageCropController: WDImageCropViewController, didFinishWithCroppedImage croppedImage: UIImage) {
		presentingController?.dismiss(animated: true)
		delegate?.imagePicker(self, pickedImage: croppedImage)
	}

	func imageCropControllerDidCancel(_ imageCropController: WDImageCropViewController) {
		presentingController?.dismiss(animated: true)
		delegate?.imagePickerDidCancel(self)
	}

	func imageCropControllerFailedCroppingImage(_ imageCropController: WDImageCropViewController) {
		presentingController?.dismiss(animated: true)
		delegate?.imagePickerDidCancel(self)
	}
}
