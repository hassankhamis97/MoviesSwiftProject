//
//  MovieReviewContract.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IMovieReviewView : IBase {
    func renderMovieReview(movieReviewList : [MovieReview])
}
protocol IMovieReviewPresenter : IPresenter {
    func getMovieReview(movieId : Int)
    func onSuccess(movieReviewList: [MovieReview])
    func onFail(errMsg : String)
}
protocol IMovieReviewModel {
    func getMovieReview(movieId : Int)
}
