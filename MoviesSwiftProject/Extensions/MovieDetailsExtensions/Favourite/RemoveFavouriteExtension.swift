//
//  RemoveFavouriteExtension.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/10/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MovieDetailsTableViewController : IRemoveMovieFavouriteView
{
    func updateFavouriteRemove(isFavourite: Bool) {
        self.isFavourite = isFavourite
        let iconImage:UIImage? = UIImage(systemName: "suit.heart")
        favouriteBtn.setBackgroundImage(iconImage, for: UIControl.State.normal)
        
    }
    
//    func updateFavouriteFlag(isFavourite: Bool) {
//        self.isFavourite = isFavourite
//    }
//    func updateFavouriteSave(isFavourite: Bool)
//    {
//        if(isFavourite == true){
//            self.isFavourite = isFavourite
//            let iconImage:UIImage? = UIImage(systemName: "suit.heart.fill")
//            favouriteBtn.setBackgroundImage(iconImage, for: UIControl.State.normal)
//        }
//
//    }
    
}
