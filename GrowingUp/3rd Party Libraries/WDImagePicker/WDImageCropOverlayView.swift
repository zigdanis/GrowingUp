//
//  WDImageCropOverlayView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

internal class WDImageCropOverlayView: UIView {

    var cropSize: CGSize!
    var toolbar: UIToolbar!

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = true
    }

    override func draw(_ rect: CGRect) {

        let toolbarSize = CGFloat(UIDevice.current.userInterfaceIdiom == .pad ? 0 : 54)

        let width = self.frame.width
        let height = self.frame.height - toolbarSize

        let heightSpan = floor(height / 2 - self.cropSize.height / 2)
        let widthSpan = floor(width / 2 - self.cropSize.width / 2)

        // fill outer rect
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).set()
        UIRectFill(self.bounds)

        // fill inner border
        UIColor(red: 1, green: 1, blue: 1, alpha: 0.5).set()
        UIRectFrame(CGRect(x: widthSpan - 2, y: heightSpan - 2, width: self.cropSize.width + 4,
            height: self.cropSize.height + 4))

        // fill inner rect
        UIColor.clear.set()
        UIRectFill(CGRect(x: widthSpan, y: heightSpan, width: self.cropSize.width, height: self.cropSize.height))
    }
}
