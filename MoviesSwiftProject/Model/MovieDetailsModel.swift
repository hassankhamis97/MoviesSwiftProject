//
//  MovieDetailsModel.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/25/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
class MovieDetailsModel : IMovieTrailerModel{
    
    
    var moviePresenterRef : IPresenter
    init(moviePresenterRef : IMovieTrailerPresenter) {
        self.moviePresenterRef = moviePresenterRef
    }
    init(moviePresenterRef : IMovieReviewPresenter) {
        self.moviePresenterRef = moviePresenterRef
    }
    func getMovieReviews(movieID : Int) {
        var movieReviewList = [MovieReview]()
        Alamofire.request("https://api.themoviedb.org/3/movie/\(movieID)/reviews?api_key=6557d01ac95a807a036e5e9e325bb3f0").validate().responseJSON { response in
            
                let json = JSON(response.data)
                for item in json["results"].arrayValue {
                    var movieReview = MovieReview()
                    
                    movieReview.author = item["author"].stringValue
                    movieReview.content = item["content"].stringValue
                    movieReview.id = item["id"].stringValue
                    movieReviewList.append(movieReview)
                }
            if let movieTrailerPresenterRef = self.moviePresenterRef as? IMovieReviewPresenter {
                movieTrailerPresenterRef.onSuccess(movieReviewList: movieReviewList)
            }
        }
    }
    func getMovieTrailer(movieId : Int) {
        var movieTrailerList = [MovieTrailer]()
        Alamofire.request("https://api.themoviedb.org/3/movie/\(movieId)/videos?api_key=6557d01ac95a807a036e5e9e325bb3f0").validate().responseJSON { response in
                let json = JSON(response.data)
                for item in json["results"].arrayValue {
                    var movieTrailer = MovieTrailer()
                    
                    movieTrailer.id = item["author"].stringValue
                    movieTrailer.key = item["key"].stringValue
                    movieTrailer.name = item["name"].stringValue
                    movieTrailer.site = item["site"].stringValue
                    movieTrailer.size = item["size"].stringValue
                    movieTrailer.type = item["type"].stringValue
                    
                    movieTrailerList.append(movieTrailer)
                    
                }
            if let movieTrailerPresenterRef = self.moviePresenterRef as? IMovieTrailerPresenter {
//                movieTrailerPresenterRef = self.moviePresenterRef as! IMovieTrailerView
                movieTrailerPresenterRef.onSuccess(movieTrailerList: movieTrailerList)
            }
        }
       
    }
}
