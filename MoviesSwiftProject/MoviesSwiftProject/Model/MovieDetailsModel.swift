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
class MovieDetailsModel {
    func getMovieReviews(movieID : Int) -> [MovieReview] {
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
            // DELEGATION ............................................
            }
        return movieReviewList
    }
}
