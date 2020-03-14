//
//  GetMoviesFavouriteContract.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/6/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IGetFavouriteView : IBase{
    func renderMoviesForUser(movieList : [Movie])
}
protocol IGetFavouriteViewPresenter : IPresenter {
    func getFavuriteMovies()
    func onSuccess(movieList : [Movie])
    func onFail(errMsg : String)
}
//protocol IMainModel {
//    func getMovies(sortOption: String)
//    func getMoviesFromCoreData(sortOption: String)
//}
