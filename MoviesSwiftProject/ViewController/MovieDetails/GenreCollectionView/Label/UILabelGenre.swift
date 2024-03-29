//
//  UILabelGenre.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/12/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit

class UILabelGenre: UILabel {
    let padding = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
//    override func drawText(in rect: CGRect) {
//        super.drawText(in: rect.inset(by: padding))
//    }

    override var intrinsicContentSize : CGSize {
        let superContentSize = super.intrinsicContentSize
        let width = superContentSize.width + padding.left + padding.right
        let heigth = superContentSize.height + padding.top + padding.bottom
        return CGSize(width: width, height: heigth)
    }
    override func drawText(in rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
//        context.stroke(self.bounds.insetBy(dx: 20.0, dy: 20.0))
        super.drawText(in: rect.insetBy(dx: 0.0, dy: 0.0))
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
