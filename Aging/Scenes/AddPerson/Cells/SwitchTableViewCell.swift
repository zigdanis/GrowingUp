//
//  SwitchTableViewCell.swift
//  Aging
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol SwitchCellView {
    func display(title: String)
    func setSwitch(isOn: Bool)
}

class SwitchTableViewCell: UITableViewCell, SwitchCellView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueSwitch: UISwitch!
    
    func display(title: String) {
        titleLabel.text = title
    }
    
    func setSwitch(isOn: Bool) {
        valueSwitch.setOn(isOn, animated: false)
    }
    
}
