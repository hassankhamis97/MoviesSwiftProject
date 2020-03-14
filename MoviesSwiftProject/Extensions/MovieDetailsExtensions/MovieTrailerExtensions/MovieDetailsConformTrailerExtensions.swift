//
//  MovieDetailsConformTrailerExtensions.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MovieDetailsTableViewController : IMovieTrailerView
{
    func renderMovieTrailer(movieTrailerList: [MovieTrailer]) {
        self.movieTrailerList = movieTrailerList
        self.trailerCollectionView.reloadData()
    }
    
  
    func showLoad() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func hideLoad() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func showErrorMsg(errMsg: String) {
        authorNameReview.text = "There is no reviews to show"
        //            contentReview.isHidden = true
        contentReview.removeFromSuperview()
        reviewBtn.removeFromSuperview()
    }
    
    
}
