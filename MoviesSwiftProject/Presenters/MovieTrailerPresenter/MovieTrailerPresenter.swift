//
//  MovieTrailerPresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class MovieTrailerPresenter : IMovieTrailerPresenter {
    var movieDetailRef : IMovieTrailerView
    init(movieDetailRef : IMovieTrailerView) {
        self.movieDetailRef = movieDetailRef
    }
    func getMovieTrailers(movieId: Int) {
        movieDetailRef.showLoad();
        var mdModel = MovieDetailsModel(moviePresenterRef: self)
        mdModel.getMovieTrailer(movieId: movieId)
    }
    
    func onSuccess(movieTrailerList: [MovieTrailer]) {
        movieDetailRef.hideLoad()
        movieDetailRef.renderMovieTrailer(movieTrailerList: movieTrailerList)
    }
    
    func onFail(errMsg: String) {
        movieDetailRef.hideLoad();
        movieDetailRef.showErrorMsg(errMsg: errMsg)
    }
    
    
}
