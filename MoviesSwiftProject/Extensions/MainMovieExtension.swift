//
//  MainMovieExtension.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/24/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MainMovieCollectionViewController : IMainView
{
    func networkStatus(isOnline: Bool) {
        if isOnline {
//            var sortBtn = UIBarButtonItem(image: UIImage(systemName: "line.horizontal.3.decrease"), style: .plain, target: self, action: #selector(sayHello(sender:))
//
//                        )
//            sortBtn.tintColor = UIColor.systemOrange
            navigationItem.rightBarButtonItems = [sortButtonBar]
            
        }
        else{
            var refreshBtn = UIBarButtonItem(
                            barButtonSystemItem: UIBarButtonItem.SystemItem.refresh, target: self, action: #selector(refresh(sender:))

                        )
            refreshBtn.tintColor = UIColor.systemOrange
            navigationItem.rightBarButtonItems = [refreshBtn]
        }
    }
    @objc func refresh(sender: UIBarButtonItem) {
        
        self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/discover/movie?api_key=6557d01ac95a807a036e5e9e325bb3f0&sort_by=popularity.desc")
    }
    
    
    func renderMoviesForUser(movieList: [Movie]) {
        self.movieList = movieList
        self.isDataLoaded = true
        if movieList.count == 0
        {
            errMsg = "There is no data to show"
        }
        //dispatch_async(dispatch_get_main_queue(),{
            self.collectionView.reloadData()
    //    })
    }
    
    func showLoad() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func hideLoad() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func showErrorMsg(errMsg: String) {
        self.errMsg = errMsg
        self.isDataLoaded = true
    }
    
    
}
