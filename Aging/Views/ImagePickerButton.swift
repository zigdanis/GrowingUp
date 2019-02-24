//
//  ImagePickerButton.swift
//  Aging
//
//  Created by zigdanis on 24/02/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class ImagePickerButton: UIButton {
    
    let maskLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override func prepareForInterfaceBuilder() {
        commonInit()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        resetCircleMask()
    }
    
    private func commonInit() {
        resetCircleMask()
        backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        appendCameraPic()
        imageView?.contentMode = .scaleAspectFill
    }
    
    private func resetCircleMask() {
        let path = CGMutablePath()
        path.addEllipse(in: squaredBounds())
        maskLayer.path = path
        layer.mask = maskLayer
    }
    
    private func squaredBounds() -> CGRect {
        let isWide = bounds.width > bounds.height
        let minSide = isWide ? bounds.height : bounds.width
        let diffSides = abs(bounds.width - bounds.height)
        let originX = isWide ? (diffSides / 2) : 0
        let originY = isWide ? 0 : (diffSides / 2)
        return CGRect(x: originX, y: originY, width: minSide, height: minSide)
    }
    
    private func appendCameraPic() {
        let cameraPic = UIImageView()
        let bundle = Bundle(for: classForCoder)
        cameraPic.image = UIImage(named: "photo-camera", in: bundle, compatibleWith: traitCollection)
        addSubview(cameraPic)
        cameraPic.translatesAutoresizingMaskIntoConstraints = false
        let consts = [
            cameraPic.widthAnchor.constraint(equalToConstant: 44),
            cameraPic.centerXAnchor.constraint(equalTo: centerXAnchor),
            cameraPic.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]
        NSLayoutConstraint.activate(consts)
    }
    
}
