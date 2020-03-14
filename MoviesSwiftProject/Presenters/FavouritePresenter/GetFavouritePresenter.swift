//
//  FavouritePresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/6/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class GetFavouritePresenter : IGetFavouriteViewPresenter {
    var getFavouriteRef : IGetFavouriteView!
    init(getFavouriteRef : IGetFavouriteView) {
        self.getFavouriteRef = getFavouriteRef
    }
    func getFavuriteMovies() {
        let coreData = CoreDataDB(presenterRef: self)
        coreData.getFavouriteMovies()
//        var movieList  = coreData.getFavouriteMovies()
//        if movieList.count > 0
//        {
//            onSuccess(movieList: movieList)
//        }
//        else{
//            onFail(errMsg: "There is no data to show")
//        }
        
    }
    
    func onSuccess(movieList: [Movie]) {
        getFavouriteRef.renderMoviesForUser(movieList: movieList)
    }
    
    func onFail(errMsg: String) {
        getFavouriteRef.showErrorMsg(errMsg: errMsg)
    }
    
    
}
