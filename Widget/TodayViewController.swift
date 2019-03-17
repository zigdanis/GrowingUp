//
//  TodayViewController.swift
//  Widget
//
//  Created by zigdanis on 15/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit
import NotificationCenter
import Core

class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var ageLabel: UILabel!
    @IBOutlet weak var faceImage: UIImageView!
    
    private var attString = NSMutableAttributedString()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFaceImage()
        setupAgeLabel()
        maintainCurrentAge()
    }
    
    private func setupFaceImage() {
        faceImage.layer.cornerRadius = faceImage.bounds.width / 2
    }
    
    private func setupAgeLabel() {
        ageLabel.minimumScaleFactor = 0.5
        ageLabel.adjustsFontSizeToFitWidth = true
        ageLabel.numberOfLines = 2
    }
    
    //MARK: - Business Logic
    
    private func maintainCurrentAge() {
        setupCurrentAge()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.setupCurrentAge()
        }
    }
    
    private func setupCurrentAge() {
        ageLabel.text = AgeCalculator.currentAge()
    }
    
    // MARK: - Actions
    
    @IBAction func widgetTouched() {
        let url = URL(string: "growingup-app://")!
        extensionContext?.open(url, completionHandler: nil)
    }
    
}
