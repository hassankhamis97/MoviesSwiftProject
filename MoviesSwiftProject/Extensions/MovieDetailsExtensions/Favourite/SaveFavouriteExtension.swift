//
//  SaveFavouriteExtension.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MovieDetailsTableViewController : ISaveMovieFavouriteView
{
//    func updateFavouriteFlag(isFavourite: Bool) {
//        self.isFavourite = isFavourite
//    }
    func updateFavouriteSave(isFavourite: Bool)
    {
        if(isFavourite == true){
            self.isFavourite = isFavourite
            let iconImage:UIImage? = UIImage(systemName: "suit.heart.fill")
            favouriteBtn.setBackgroundImage(iconImage, for: UIControl.State.normal)
        }
        
    }
    
}
