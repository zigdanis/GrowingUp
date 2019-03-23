//
//  ViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit
import Core

class ViewController: UIViewController {

    @IBOutlet weak var ageLabel: UILabel!
    @IBOutlet weak var kidImage: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMainImage()
        maintainCurrentAge()
    }

    private func setupMainImage() {
        kidImage.layer.cornerRadius = 8
    }

    private func maintainCurrentAge() {
        setupCurrentAge()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.setupCurrentAge()
        }
    }

    private func setupCurrentAge() {
        ageLabel.text = AgeCalculator.currentAge()
    }

}
