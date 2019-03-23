//
//  NewPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

class NewPersonViewController: UIViewController {

    @IBOutlet weak var addPersonButton: VerticalButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAddPersonButton()
    }

    private func setupAddPersonButton() {
        let title = R.string.localizable.addPerson()
        addPersonButton.setTitle(title, for: .normal)
    }

    // MARK: - Actions

    @IBAction func addNewPersonTouched() {

    }
}
