//
//  MovieTrailerCollectionViewCell.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import youtube_ios_player_helper
import Cosmos
class MovieTrailerCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var movieTrailerYoutube: YTPlayerView!
    
//    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
//        setNeedsLayout()
//        layoutIfNeeded()
//        let size = contentView.systemLayoutSizeFitting(layoutAttributes.size)
//        var frame = layoutAttributes.frame
//        frame.size.height = ceil(size.height)
//        layoutAttributes.frame = frame
//        return layoutAttributes
//    }
//    override open func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
//    if #available(iOS 12.0, tvOS 12.0, *)
//    {
//        /*
//        In iOS 12, there are issues with self-sizing cells. The fix is to call updateConstraintsIfNeeded() and turn on translatesAutoResizingMaskIntoConstraints as described in Apples release notes:
//        "You might encounter issues with systemLayoutSizeFitting(_:) when using a UICollectionViewCell subclass that requires updateConstraints(). (42138227) — Workaround: Don't call the cell's setNeedsUpdateConstraints() method unless you need to support live constraint changes. If you need to support live constraint changes, call updateConstraintsIfNeeded() before calling systemLayoutSizeFitting(_:)."
//        */
//        self.updateConstraintsIfNeeded()
////      if let flowLayout = collectionview.collectionViewLayout as? UICollectionViewFlowLayout {
////      //        flowLayout.estimatedItemSize = CGSize(width: 414 , height: 231)
////                  flowLayout.estimatedItemSize = flowLayout.itemSize
//        }
//    return super.preferredLayoutAttributesFitting(layoutAttributes)
//        
//    }
}
