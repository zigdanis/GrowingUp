//
//  ImagePickerButton.swift
//  GrowingUp
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

    func drawImage(_ image: UIImage) {
        let circle = image.circleImage(for: CGSize(width: 300, height: 300))
        setBackgroundImage(circle, for: .normal)
    }

    // MARK: - Private

    private func commonInit() {
        resetCircleMask()
        backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        appendCameraPic()
    }

    private func resetCircleMask() {
        let path = CGMutablePath()
        path.addEllipse(in: squaredBounds())
        maskLayer.path = path
        layer.mask = maskLayer
    }

    private func appendCameraPic() {
        imageView?.contentMode = .scaleAspectFill
        let bundle = Bundle(for: classForCoder)
        let image = UIImage(named: "photo-camera", in: bundle, compatibleWith: traitCollection)
        setImage(image, for: .normal)
    }

    // MARK: - Helpers

    private func squaredBounds() -> CGRect {
        let isWide = bounds.width > bounds.height
        let minSide = isWide ? bounds.height : bounds.width
        let diffSides = abs(bounds.width - bounds.height)
        let originX = isWide ? (diffSides / 2) : 0
        let originY = isWide ? 0 : (diffSides / 2)
        return CGRect(x: originX, y: originY, width: minSide, height: minSide)
    }

}
