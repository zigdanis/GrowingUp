//
//  WDCropBorderView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

internal class WDCropBorderView: UIView {
    fileprivate let kNumberOfBorderHandles: CGFloat = 8
    fileprivate let kHandleDiameter: CGFloat = 24

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.backgroundColor = UIColor.clear
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        context?.setStrokeColor(UIColor(red: 1, green: 1, blue: 1, alpha: 0.5).cgColor)
        context?.setLineWidth(1.5)
        context?.addRect(CGRect(x: kHandleDiameter / 2, y: kHandleDiameter / 2,
            width: rect.size.width - kHandleDiameter, height: rect.size.height - kHandleDiameter))
        context?.strokePath()

        context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.95)
        for handleRect in calculateAllNeededHandleRects() {
            context?.fillEllipse(in: handleRect)
        }
    }

    fileprivate func calculateAllNeededHandleRects() -> [CGRect] {

        let width = self.frame.width
        let height = self.frame.height

        let leftColX: CGFloat = 0
        let rightColX = width - kHandleDiameter
        let centerColX = rightColX / 2

        let topRowY: CGFloat = 0
        let bottomRowY = height - kHandleDiameter
        let middleRowY = bottomRowY / 2

        //starting with the upper left corner and then following clockwise
        let topLeft = CGRect(x: leftColX, y: topRowY, width: kHandleDiameter, height: kHandleDiameter)
        let topCenter = CGRect(x: centerColX, y: topRowY, width: kHandleDiameter, height: kHandleDiameter)
        let topRight = CGRect(x: rightColX, y: topRowY, width: kHandleDiameter, height: kHandleDiameter)
        let middleRight = CGRect(x: rightColX, y: middleRowY, width: kHandleDiameter, height: kHandleDiameter)
        let bottomRight = CGRect(x: rightColX, y: bottomRowY, width: kHandleDiameter, height: kHandleDiameter)
        let bottomCenter = CGRect(x: centerColX, y: bottomRowY, width: kHandleDiameter, height: kHandleDiameter)
        let bottomLeft = CGRect(x: leftColX, y: bottomRowY, width: kHandleDiameter, height: kHandleDiameter)
        let middleLeft = CGRect(x: leftColX, y: middleRowY, width: kHandleDiameter, height: kHandleDiameter)

        return [topLeft, topCenter, topRight, middleRight, bottomRight, bottomCenter, bottomLeft,
            middleLeft]
    }
}
