//
//  LabelTableViewCell.swift
//  GrowingUp
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol DateCellView {
    func display(title: String)
    func display(value: String)
}

final class DateTableViewCell: UITableViewCell, DateCellView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    func display(title: String) {
        titleLabel.text = title
    } 
    
    func display(value: String) {
        valueLabel.text = value
    }
	
}
