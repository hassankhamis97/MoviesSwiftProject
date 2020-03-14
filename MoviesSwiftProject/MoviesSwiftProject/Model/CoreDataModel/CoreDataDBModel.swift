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
class CoreDataDB {
    func getMovies() -> [Movie] {
        var movieList = [Movie]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let manageContext = appDelegate.persistentContainer.viewContext

        let movie = MovieEntity(context: manageContext)
    
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MovieEntity")
                fetchRequest.returnsObjectsAsFaults = false;
                fetchRequest.relationshipKeyPathsForPrefetching = ["movieGenreFK"]
        
        do{
                            var moviesArray: [MovieEntity]
                            moviesArray = try manageContext.fetch(fetchRequest) as! [MovieEntity]
                            
                            for item in moviesArray {
                                if item.title == nil {
                                   continue
                                }
                                var tempMovie = Movie()
                                tempMovie.title = item.value(forKey: "title")! as! String
                                tempMovie.image = item.value(forKey: "image")! as! String
                                tempMovie.rating = item.value(forKey: "rating")! as! Float
                                tempMovie.releaseDate = item.value(forKey: "releaseDate")! as! String

                                if let sets : NSArray = item.movieGenreFK?.allObjects as NSArray? { //assuming you have name your to-many relationship 'sets'
                                    var count = 1

                                    var genreArray : Array<String> = sets.value(forKey: "genreName") as! Array<String>
                                    tempMovie.genre = [String]()
                                    for genre in genreArray {
                                        tempMovie.genre.append(genre)
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
        
        
            for item in parentItem.genre {
                        let genreObject = GenreEntity(context : manageContext)
                
                genreObject.genreName = item
                genreObject.movieGenreFK = movie
//                movie.addToRelationship(genreObject)
                movie.addToMovieGenreFK(genreObject)
//                movie.addToRelationship(genreObject)
            }

            movie.image = parentItem.image
            movie.title =  parentItem.title
            movie.rating =  parentItem.rating
            movie.releaseDate =  parentItem.releaseDate
            
        }
        
        do{
                    
                    try manageContext.save()
                    status = true
        //            moviesArray.append(movie)
                    
                    
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
     

}
