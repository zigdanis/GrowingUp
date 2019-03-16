//
//  TextFieldTableVIewCell.swift
//  Aging
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol TextFieldCellView {
    func display(title: String)
    func display(value: String)
    func display(placeholder: String)
}

class TextFieldTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueField: UITextField!
    
    func display(title: String) {
        titleLabel.text = title
    }
    
    func display(placeholder: String) {
        
    }
    
    func display(value: String) {
        valueField.text = value
    }
    
}
