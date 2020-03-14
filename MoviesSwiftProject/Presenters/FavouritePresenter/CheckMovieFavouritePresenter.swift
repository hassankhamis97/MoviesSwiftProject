//
//  CheckMovieFavouritePresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class CheckMovieFavouritePresenter: ICheckMovieFavouritePresenter {
   
    
    var checkFavouriteRef : ICheckMovieFavouriteView!
    init(checkFavouriteRef : ICheckMovieFavouriteView) {
        self.checkFavouriteRef = checkFavouriteRef
    }
    func checkFavuriteMovies(movieID : Int) {
        let coreData = CoreDataDB(presenterRef: self)
        var result  = coreData.checkFavouriteMovies(movieID: movieID)
    }
    
    func result(count: Int) {
        if count > 0 {
            checkFavouriteRef.updateFavouriteFlag(isFavourite: true)
        }
        else{
            checkFavouriteRef.updateFavouriteFlag(isFavourite: false)
        }
       }
    
    
}
