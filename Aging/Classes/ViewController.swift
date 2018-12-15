//
//  ViewController.swift
//  Aging
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit

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
        
        let initial = DateComponents(year: 2018, month: 10, day: 20, hour: 13, minute: 25, second: 0)
        let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: initial, to: now)
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let days = comps.day ?? 0
        let hours = comps.hour ?? 0
        let minutes = comps.minute ?? 0
        let seconds = comps.second ?? 0
        
        var result = ""
        if years > 0 {
            result += " " + String(format: NSLocalizedString("%li years", comment: "Years"), years)
        }
        if months > 0 {
            result += " " + String(format: NSLocalizedString("%li months", comment: "Months"), months)
        }
        if days > 0 {
            result += " " + String(format: NSLocalizedString("%li days", comment: "Days"), days)
        }
        if hours > 0 {
            result += " " + String(format: NSLocalizedString("%li hours", comment: "Hour"), hours)
        }
        if minutes > 0 {
            result += " " + String(format: NSLocalizedString("%li minutes", comment: "Minutes"), minutes)
        }
        if seconds > 0 {
            result += " " + String(format: NSLocalizedString("%li seconds", comment: "Seconds"), seconds)
        }
        ageLabel.text = result.trimmingCharacters(in: .whitespaces)
    }
    
    
}

