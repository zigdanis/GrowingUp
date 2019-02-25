//
//  SettingsViewController.swift
//  Aging
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var appPicButton: ImagePickerButton!
    @IBOutlet weak var widgetPicButton: ImagePickerButton!
    @IBOutlet weak var appPicLabel: UILabel!
    @IBOutlet weak var widgetPicLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupImagePickerViews()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }
    
    private func setupImagePickerViews() {
        appPicLabel.text = NSLocalizedString("app pic", comment: "text on label under app pic rounded button")
        widgetPicLabel.text = NSLocalizedString("widget pic", comment: "text on label under widget pic rounded button")
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        
    }
    
    @objc private func doneTapped() {
        
    }
}
