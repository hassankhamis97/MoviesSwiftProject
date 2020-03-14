//
//  MainModel.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/23/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import Alamofire
//import SDWebImage
import SwiftyJSON

class MainModel {
    var presenterRef : IMainPresenter
    init(presenterRef : IMainPresenter) {
        self.presenterRef = presenterRef
    }
    func getMovies(sortOption: String) {
        var movieList = [Movie]()
        Alamofire.request("https://api.themoviedb.org/3/discover/movie?api_key=6557d01ac95a807a036e5e9e325bb3f0&sort_by=popularity.desc").validate().responseJSON { response in
            debugPrint(response)
            let json = JSON(response.data)
            print(json)
            
                for item in json["results"].arrayValue {
                    var movie = Movie()
                    var prepareGenre = [String]()
                    movie.title = item["title"].stringValue
                    movie.image = item["poster_path"].stringValue
//                    var preGenre = item["genre_ids"].arrayObject!
                    for j in item["genre_ids"].arrayObject! {
                        prepareGenre.append(String(j as! Int))
                    }
                    movie.genre = prepareGenre
                    movie.releaseDate = item["release_date"].stringValue
                    movie.rating = item["vote_average"].floatValue
                    movie.id = item["id"].intValue
                    movie.overview = item["overview"].stringValue
                    movieList.append(movie)
                }
            var cdDB = CoreDataDB()
            cdDB.deleteMovies()
            cdDB.saveMovies(movieArray: movieList)
            self.presenterRef.onSuccess(movieList : movieList)
//            var dbObj = Database()
//            db.
        }
        
    }
    func getMoviesFromCoreData(sortOption: String) {
        var cdDB = CoreDataDB()
//        var movieList = [Movie]()
         var movieList = cdDB.getMovies()
        self.presenterRef.onSuccess(movieList : movieList)
    }
}
