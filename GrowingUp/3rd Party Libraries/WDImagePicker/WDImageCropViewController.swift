//
//  WDImageCropViewController.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

protocol WDImageCropControllerDelegate: class {
    func imageCropController(_ imageCropController: WDImageCropViewController, didFinishWithCroppedImage croppedImage: UIImage)
}

class WDImageCropViewController: UIViewController {

	let sourceImage: UIImage
    weak var delegate: WDImageCropControllerDelegate?
    let cropSize: CGSize

	private let imageCropView: WDImageCropView
    private let toolbar = UIToolbar(frame: .zero)
    private let useButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .custom)

	init(sourceImage: UIImage, cropSize: CGSize) {
		self.sourceImage = sourceImage
		self.cropSize = cropSize
		imageCropView = WDImageCropView(imageToCrop: sourceImage, cropSize: cropSize)
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "Class doesn not intended to be created from xib")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCropView()
		setupToolbar()
		navigationController?.isNavigationBarHidden = true
    }

    @objc private func cancelTapped() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func useTapped() {
        let croppedImage = imageCropView.croppedImage()
        delegate?.imageCropController(self, didFinishWithCroppedImage: croppedImage)
    }

    private func setupCropView() {
		imageCropView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageCropView)
		let consts = [
			imageCropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: imageCropView.trailingAnchor),
			imageCropView.topAnchor.constraint(equalTo: view.topAnchor)
		]
		NSLayoutConstraint.activate(consts)
    }

	private func setupToolbar() {
		toolbar.isTranslucent = true
		toolbar.barStyle = .black
		let cancel = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(cancelTapped))
		let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let use = UIBarButtonItem(title: R.string.localizable.use(), style: .plain, target: self, action: #selector(useTapped))
		toolbar.setItems([cancel, flex, use], animated: false)

		toolbar.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(toolbar)
		let consts = [
			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			toolbar.topAnchor.constraint(equalTo: imageCropView.bottomAnchor),
			view.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
			view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
	}
}
