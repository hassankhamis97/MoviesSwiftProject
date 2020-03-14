//
//  CheckMovieFavouriteContract.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol ICheckMovieFavouriteView : IBase{
    func updateFavouriteFlag(isFavourite : Bool)
}
protocol ICheckMovieFavouritePresenter : IPresenter {
    func checkFavuriteMovies(movieID : Int)
    func result(count : Int)
}
