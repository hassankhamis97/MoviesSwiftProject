//
//  CheckFavouriteExtension.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MovieDetailsTableViewController : ICheckMovieFavouriteView
{
    func updateFavouriteFlag(isFavourite: Bool) {
        self.isFavourite = isFavourite
        if isFavourite == false
        {
            let iconImage:UIImage? = UIImage(systemName: "suit.heart")
            favouriteBtn.setBackgroundImage(iconImage, for: UIControl.State.normal)

        }
        else{
            let iconImage:UIImage? = UIImage(systemName: "suit.heart.fill")
            favouriteBtn.setBackgroundImage(iconImage, for: UIControl.State.normal)
        }
    }
    
    
}

