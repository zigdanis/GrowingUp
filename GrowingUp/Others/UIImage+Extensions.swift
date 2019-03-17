//
//  UIImage+Extensions.swift
//  GrowingUp
//
//  Created by zigdanis on 25/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    
    func squareImage(for size: CGSize) -> UIImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")
        let side = min(size.width, size.height)
        let isWide = self.size.width > self.size.height
        let resizeFactor = isWide ? side / self.size.height : side / self.size.width
        let scaledSize = CGSize(width: self.size.width * resizeFactor,
                                height: self.size.height * resizeFactor)
        let origin = CGPoint(x: (side - scaledSize.width) / 2.0,
                             y: (side - scaledSize.height) / 2.0)
        
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        draw(in: CGRect(origin: origin, size: scaledSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    func circleImage(for size: CGSize) -> UIImage {
        let radius = min(size.width, size.height) / 2.0
        let square = squareImage(for: size)
        let squareRect = CGRect(origin: CGPoint.zero, size: square.size)
        
        UIGraphicsBeginImageContextWithOptions(square.size, false, 0.0)
        let clippingPath = UIBezierPath(roundedRect: squareRect, cornerRadius: radius)
        clippingPath.addClip()
        square.draw(in: squareRect)
        drawShadeOnTop(in: squareRect)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return roundedImage
    }
    
    func drawShadeOnTop(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5040713028))
        context.fill(rect)
    }
}
