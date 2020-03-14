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
        var cdDB = CoreDataDB()
        if cdDB.allGenreList.count == 0 {
            fillAllGenreList(cdDBRef: cdDB)
        }
                var movieList = [Movie]()
        Alamofire.request(sortOption).validate().responseJSON { response in
            debugPrint(response)
            let json = JSON(response.data)
            print(json)
            
                for item in json["results"].arrayValue {
                    var movie = Movie()
                    var prepareGenre = [Int]()
                    var prepareGenreName = [String]()
                    movie.title = item["title"].stringValue
                    movie.image = item["poster_path"].stringValue
//                    var preGenre = item["genre_ids"].arrayObject!
                    for j in item["genre_ids"].arrayObject! {
                        prepareGenre.append(j as! Int)
                        prepareGenreName.append(cdDB.getGenreName(genreID: j as! Int))
                    }
                    movie.genreId = prepareGenre
                    movie.genreName = prepareGenreName
                    movie.releaseDate = item["release_date"].stringValue
                    movie.rating = item["vote_average"].floatValue
                    movie.id = item["id"].intValue
                    movie.overview = item["overview"].stringValue
                    movieList.append(movie)
                }
            
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
    func fillAllGenreList(cdDBRef : CoreDataDB){
    //        var gg = Genre(id: <#T##Int#>, name: <#T##String#>)
    //        allGenreList = [Genre(id: 28, name: "Action"),Genre(id: 12, name:  "Adventure")
    //        ,Genre(id: 16, name:  "Animation"),Genre(id: 35, name:  "Comedy")
    //        ,Genre(id: 80, name:  "Crime"),Genre(id: 99, name:  "Adventure")]
            Alamofire.request("https://api.themoviedb.org/3/genre/movie/list?api_key=6557d01ac95a807a036e5e9e325bb3f0").validate().responseJSON { response in
                debugPrint(response)
                let json = JSON(response.data)
                for item in json["genres"].arrayValue {
                    var genreObj = Genre()
                    genreObj.id = item["id"].intValue
                    genreObj.name = item["name"].stringValue
                    cdDBRef.allGenreList.append(genreObj)
                }
            }
         
        }
}

