//
//  LabelTableViewCell.swift
//  Aging
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol LabelCellView {
    func display(title: String)
    func display(value: String)
}

class LabelTableViewCell: UITableViewCell, LabelCellView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    func display(title: String) {
        titleLabel.text = title
    } 
    
    func display(value: String) {
        valueLabel.text = value
    }
    
}
