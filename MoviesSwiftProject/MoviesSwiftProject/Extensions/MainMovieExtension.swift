//
//  MainMovieExtension.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/24/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
extension MainMovieCollectionViewController : IMainView
{
    func renderMoviesForUser(movieList: [Movie]) {
        self.movieList = movieList
        //dispatch_async(dispatch_get_main_queue(),{
            self.collectionView.reloadData()
    //    })
    }
    
    func showLoad() {
        
    }
    
    func hideLoad() {
        
    }
    
    func showErrorMsg(errMsg: String) {
        
    }
    
    
}
