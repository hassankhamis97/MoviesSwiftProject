//
//  SaveFavouriteMovie.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol ISaveMovieFavouriteView : IBase{
    func updateFavouriteSave(isFavourite : Bool)
}
protocol ISaveMovieFavouritePresenter : IPresenter {
    func saveFavuriteMovies(movieObj : Movie)
    
    func onSuccess()
    func onFail(errMsg : String)
}
