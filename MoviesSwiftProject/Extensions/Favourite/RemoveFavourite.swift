//
//  RemoveFavourite.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/10/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
extension FavouriteTableViewController : IRemoveMovieFavouriteView
{
    func updateFavouriteRemove(isFavourite: Bool) {
//        movieList = [Movie]()
        tableView.reloadData()
    }
    
    
}
