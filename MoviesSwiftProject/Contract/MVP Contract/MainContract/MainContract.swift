//
//  MainContract.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/24/20.
// Copyright  2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IMainView : IBase{
    func renderMoviesForUser(movieList : [Movie])
    func networkStatus(isOnline: Bool)
}
protocol IMainPresenter : IPresenter {
    func getMovies(sortOption: String)
    func onSuccess(movieList : [Movie])
    func onFail(errMsg : String)
}
protocol IMainModel {
    func getMovies(sortOption: String)
    func getMoviesFromCoreData(sortOption: String)
}
