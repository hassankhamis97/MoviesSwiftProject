//
//  SaveMovieFavouritePresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class SaveMovieFavouritePresenter: ISaveMovieFavouritePresenter {

    
    var saveFavouriteRef : ISaveMovieFavouriteView!
    init(saveFavouriteRef : ISaveMovieFavouriteView) {
        self.saveFavouriteRef = saveFavouriteRef
    }

    func saveFavuriteMovies(movieObj: Movie) {
        let coreData = CoreDataDB(presenterRef: self)
        coreData.addMovieToFavourite(movieObj: movieObj)
    }
    func onSuccess() {
        saveFavouriteRef.updateFavouriteSave(isFavourite: true)
    }
    
    func onFail(errMsg: String) {
        saveFavouriteRef.showErrorMsg(errMsg: errMsg)
        saveFavouriteRef.updateFavouriteSave(isFavourite: false)
    }
    
    
}
