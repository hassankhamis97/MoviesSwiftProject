//
//  DatabaseModel.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/23/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import Alamofire
class CoreDataDB {
    var favuritePresenterRef : IPresenter?
    var allGenreList = [Genre]()

    init() {
        
    }
    init(presenterRef : IGetFavouriteViewPresenter) {
        self.favuritePresenterRef = presenterRef
    }
    init(presenterRef : ICheckMovieFavouritePresenter) {
        self.favuritePresenterRef = presenterRef
    }
    init(presenterRef : ISaveMovieFavouritePresenter) {
        self.favuritePresenterRef = presenterRef
    }
    init(presenterRef : IRemoveMovieFavouritePresenter) {
        self.favuritePresenterRef = presenterRef
    }
    
    func getMovies() -> [Movie] {
        var movieList = [Movie]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let manageContext = appDelegate.persistentContainer.viewContext

        let movie = MovieEntity(context: manageContext)
    
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MovieEntity")
                fetchRequest.returnsObjectsAsFaults = false;
                fetchRequest.relationshipKeyPathsForPrefetching = ["movieGenreFK"]
//        fetchRequest.predicate =
        
        do{
                            var moviesArray: [MovieEntity]
                            moviesArray = try manageContext.fetch(fetchRequest) as! [MovieEntity]
                            
                            for item in moviesArray {
                                if item.title == nil {
                                    manageContext.delete(item)
                                    try manageContext.save()
                                   continue
                                }
                                var tempMovie = Movie()
                                tempMovie.id = item.value(forKey: "id")! as! Int
                                tempMovie.title = item.value(forKey: "title")! as! String
                                tempMovie.image = item.value(forKey: "image")! as! String
                                tempMovie.rating = item.value(forKey: "rating")! as! Float
                                tempMovie.releaseDate = item.value(forKey: "releaseDate")! as! String
                                tempMovie.overview = item.value(forKey: "overview")! as! String

                                if let sets : NSArray = item.movieGenreFK?.allObjects as NSArray? { //assuming you have name your to-many relationship 'sets'
                                    var count = 1

                                    var genreArray : Array<String> = sets.value(forKey: "genreName") as! Array<String>
                                    
                                    tempMovie.genreName = [String]()
                                    for genre in genreArray {
                                        tempMovie.genreName.append(genre)
                                    }
                                    var genreIDArray : Array<Int> = sets.value(forKey: "genreid") as! Array<Int>
                                    
                                    tempMovie.genreId = [Int]()
                                    for genre in genreIDArray {
                                        tempMovie.genreId.append(genre)
                                    }

                                    print(sets.count)
                                }
                                movieList.append(tempMovie)
                            }

                        }catch let error{


                            print(error)

                        }
        return movieList
        }
        
        
    func saveMovies(movieArray : [Movie]) -> Bool {
        var status : Bool = false
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let manageContext = appDelegate.persistentContainer.viewContext
        for parentItem in movieArray {
            let movie = MovieEntity(context: manageContext)
            for item in parentItem.genreId {
                        let genreObject = GenreEntity(context : manageContext)
                
                genreObject.genreid = Int64(item)
                genreObject.genreName = getGenreName(genreID: item)
                genreObject.movieGenreFK = movie
                movie.addToMovieGenreFK(genreObject)
            }
            movie.id = Int64(Int(parentItem.id))
            movie.image = parentItem.image
            movie.title =  parentItem.title
            movie.rating =  parentItem.rating
            movie.releaseDate =  parentItem.releaseDate
            movie.overview =  parentItem.overview
        }
        do{
                    
            try manageContext.save()
                status = true
            }catch let error{
                    print(error)
            }
            return status;
    }

    func deleteMovies() -> Bool {
        var status : Bool = false
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let manageContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MovieEntity")
        fetchRequest.returnsObjectsAsFaults = false;
        fetchRequest.relationshipKeyPathsForPrefetching = ["movieGenreFK"]
        do{
        var moviesArray = try manageContext.fetch(fetchRequest)
        for item in moviesArray {
            manageContext.delete(item)
        }
        
                    
                    try manageContext.save()
                    status = true
        //            moviesArray.append(movie)
                    
                    
                }catch let error{
                    
                    print(error)
                }
        return status
    }
    //     //          //       //    Favourite    //     //          //       //
    func addMovieToFavourite(movieObj : Movie){
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let manageContext = appDelegate.persistentContainer.viewContext

                    let movie = FavouriteMovies(context: manageContext)
                
                
        for index in 0..<movieObj.genreId.count {
                                let genreObject = GenreEntity(context : manageContext)
                        
                        genreObject.genreid = Int64(movieObj.genreId[index])
                        genreObject.genreName = movieObj.genreName[index]
                        genreObject.favouriteGenreFK = movie
                        movie.addToFavouriteGenreFK(genreObject)

                    }
                    movie.id = Int64(Int(movieObj.id))
                    movie.image = movieObj.image
                    movie.title =  movieObj.title
                    movie.rating =  movieObj.rating
                    movie.releaseDate =  movieObj.releaseDate
                    movie.overview = movieObj.overview
    

                do{
                            
                            try manageContext.save()
                    if let saveFavuritePresenterRef = self.favuritePresenterRef as? ISaveMovieFavouritePresenter {
                        saveFavuritePresenterRef.onSuccess()
                        
                    }
                            
                            
                        }catch let error{
                            
                            if let saveFavuritePresenterRef = self.favuritePresenterRef as? ISaveMovieFavouritePresenter {
                                    saveFavuritePresenterRef.onFail(errMsg: error as! String)
                                                   
                            }
                        }
    }
    func deleteMovieFromFavourite(movieID : Int){
        var status : Bool = false
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let manageContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FavouriteMovies")
        fetchRequest.returnsObjectsAsFaults = false;
        fetchRequest.relationshipKeyPathsForPrefetching = ["favouriteGenreFK"]
        let predicate = NSPredicate(format: "id = %lld", movieID)
        fetchRequest.predicate = predicate
        
            do{
                var moviesArray = try manageContext.fetch(fetchRequest)
            if(moviesArray.count > 0)
            {
                manageContext.delete(moviesArray[0])
            }
                try manageContext.save()
                    if let removeFavuritePresenterRef = self.favuritePresenterRef as? IRemoveMovieFavouritePresenter {
                        removeFavuritePresenterRef.onSuccess()
                    }
                }catch let error{
                    if let removeFavuritePresenterRef = self.favuritePresenterRef as? IRemoveMovieFavouritePresenter {
                        removeFavuritePresenterRef.onFail(errMsg: error as! String)
                    }
                    print(error)
                }
        
    }
    func getFavouriteMovies(){
        var movieList = [Movie]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let manageContext = appDelegate.persistentContainer.viewContext

        let movie = FavouriteMovies(context: manageContext)
    
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FavouriteMovies")
                fetchRequest.returnsObjectsAsFaults = false;
                fetchRequest.relationshipKeyPathsForPrefetching = ["favouriteGenreFK"]
        
        do{
                            var moviesArray: [FavouriteMovies]
                            moviesArray = try manageContext.fetch(fetchRequest) as! [FavouriteMovies]
                            
                            for item in moviesArray {
                                if item.title == nil {
                                    manageContext.delete(item)
                                    try manageContext.save()
                                   continue
                                }
                                var tempMovie = Movie()
                                tempMovie.id = item.value(forKey: "id")! as! Int
                                tempMovie.title = item.value(forKey: "title")! as! String
                                tempMovie.image = item.value(forKey: "image")! as! String
                                tempMovie.rating = item.value(forKey: "rating")! as! Float
                                tempMovie.releaseDate = item.value(forKey: "releaseDate")! as! String
                                tempMovie.overview = item.value(forKey: "overview")! as! String

                                if let sets : NSArray = item.favouriteGenreFK?.allObjects as NSArray? { //assuming you have name your to-many relationship 'sets'
                                    var count = 1

                                    var genreArray : Array<String> = sets.value(forKey: "genreName") as! Array<String>
                                    tempMovie.genreName = [String]()
                                    for genre in genreArray {
                                        tempMovie.genreName.append(genre)
                                    }

                                    print(sets.count)
                                }
                                movieList.append(tempMovie)
                            }
            if movieList.count > 0 {
                if let getFavuritePresenterRef = self.favuritePresenterRef as? IGetFavouriteViewPresenter {
                    getFavuritePresenterRef.onSuccess(movieList :movieList)

                }
                
                            }
            else{
                if let getFavuritePresenterRef = self.favuritePresenterRef as? IGetFavouriteViewPresenter {
                    getFavuritePresenterRef.onFail(errMsg: "There is no data to show")

                }
            }

                        }catch let error{


                            if let getFavuritePresenterRef = self.favuritePresenterRef as? IGetFavouriteViewPresenter {
                                getFavuritePresenterRef.onFail(errMsg: error as! String)

                            }


                        }
        }
    func checkFavouriteMovies(movieID : Int) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let manageContext = appDelegate.persistentContainer.viewContext

        let movie = FavouriteMovies(context: manageContext)
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FavouriteMovies")
        fetchRequest.returnsObjectsAsFaults = false;
        let predicate = NSPredicate(format: "id = %lld", movieID)
        fetchRequest.predicate = predicate
        do{
            var movieObj = [FavouriteMovies]()
            movieObj = try manageContext.fetch(fetchRequest) as! [FavouriteMovies]
            
                if let checkFavuritePresenterRef = self.favuritePresenterRef as? ICheckMovieFavouritePresenter {
                    checkFavuritePresenterRef.result(count: movieObj.count)
                }
            
        }
        catch let error{
            
        }
        
    }
//    func saveGenre(genreArray : [Genre]) -> Bool {
//        var status : Bool = false
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        let manageContext = appDelegate.persistentContainer.viewContext
//        for parentItem in genreArray {
//            let genreObj = AllGenre(context: manageContext)
//            genreObj.id = Int64(Int(parentItem.id))
//            genreObj.name = parentItem.name
//        }
//        do{
//                    
//            try manageContext.save()
//                status = true
//            }catch let error{
//                    print(error)
//            }
//            return status;
//    }
    func getGenreName(genreID : Int) -> String {
        for item in allGenreList {
            if item.id == genreID {
                return item.name!
            }
        }
        return "Genre Not Found"
    }
    
}
