//
//  MovieReviewPresenter.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
class MovieReviewPresenter : IMovieReviewPresenter {
    
    
    var movieDetailRef : IMovieReviewView
    init(movieDetailRef : IMovieReviewView) {
        self.movieDetailRef = movieDetailRef
    }
    func getMovieReview(movieId: Int) {
        var mdModel = MovieDetailsModel(moviePresenterRef: self)
        mdModel.getMovieReviews(movieID: movieId)
    }
    
    func onSuccess(movieReviewList: [MovieReview]) {
        movieDetailRef.renderMovieReview(movieReviewList: movieReviewList)
    }
    
    func onFail(errMsg: String) {
        movieDetailRef.showErrorMsg(errMsg: errMsg)
    }
    
    
}
