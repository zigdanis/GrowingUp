//
//  UIViewController+Extensions.swift
//  GrowingUp
//
//  Created by zigdanis on 17/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

extension UIViewController {

  func showAlert(title: String = String(localized: "Alert"), message: String) {
    let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alertVC, animated: true)
  }
}
