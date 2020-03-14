//
//  removeMovieFavouritePresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/9/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class RemoveMovieFavouritePresenter: IRemoveMovieFavouritePresenter {
    var removeFavouriteRef : IRemoveMovieFavouriteView!
    init(removeFavouriteRef : IRemoveMovieFavouriteView) {
        self.removeFavouriteRef = removeFavouriteRef
    }

    func removeFavuriteMovies(movieID : Int) {
        let coreData = CoreDataDB(presenterRef: self)
        coreData.deleteMovieFromFavourite(movieID : movieID)
    }
    func onSuccess() {
        removeFavouriteRef.updateFavouriteRemove(isFavourite: false)
    }

    func onFail(errMsg: String) {
        removeFavouriteRef.showErrorMsg(errMsg: errMsg)
    //    removeFavouriteRef.updateFavouriteSave(isFavourite: false)
    }
}
