//
//  MovieTrailerContract.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IMovieTrailerView: IBase {
    func renderMovieTrailer(movieTrailerList : [MovieTrailer])
    
}
protocol IMovieTrailerPresenter : IPresenter {
    func getMovieTrailers(movieId : Int)
    func onSuccess(movieTrailerList : [MovieTrailer])
    func onFail(errMsg : String)
}
protocol IMovieTrailerModel {
    func getMovieTrailer(movieId : Int)
}
