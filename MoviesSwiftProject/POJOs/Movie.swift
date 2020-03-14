//
//  Movie.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/23/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
struct Movie: Codable {
    var title : String!;
    var image : String!;
    var rating : Float!;
    var releaseDate : String!;
//    var genre : [Dictionary<Int,String>]!;
    var genreId : [Int]!;
    var genreName : [String]!;
    var id : Int!
    var overview : String!

    
}
