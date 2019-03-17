//
//  GradientView.swift
//  GrowingUp
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class GradientView: UIView {
    
    @IBInspectable var startColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }
    
    @IBInspectable var endColor = #colorLiteral(red: 0.8470588235, green: 0.8470588235, blue: 0.8470588235, alpha: 1) {
        didSet { setNeedsDisplay() }
    }
    
    private let gradient = CAGradientLayer()
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = bounds
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        gradient.frame = bounds
        gradient.colors = [startColor.cgColor, endColor.cgColor]
        gradient.startPoint = CGPoint.init(x: 0.5, y: 0)
        gradient.endPoint = CGPoint.init(x: 0.5, y: 1)
        if gradient.superlayer == nil {
            layer.insertSublayer(gradient, at: 0)
        }
    }
}
