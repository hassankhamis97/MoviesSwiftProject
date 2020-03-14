//
//  RemoveFavouriteMovie.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/9/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IRemoveMovieFavouriteView : IBase{
    func updateFavouriteRemove(isFavourite : Bool)
}
protocol IRemoveMovieFavouritePresenter : IPresenter {
    func removeFavuriteMovies(movieID : Int)
    
    func onSuccess()
    func onFail(errMsg : String)
}
