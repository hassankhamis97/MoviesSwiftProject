//
//  MovieDetailsReviewExtension.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
extension MovieDetailsTableViewController : IMovieReviewView
{
    func renderMovieReview(movieReviewList: [MovieReview]) {
        self.movieReviewList = movieReviewList
        if(movieReviewList.count > 0)
        {
            authorNameReview.text = movieReviewList[0].author
            contentReview.text = movieReviewList[0].content
        }
        else
        {
            authorNameReview.text = "There is no reviews to show"
//            contentReview.isHidden = true
            contentReview.removeFromSuperview()
            reviewBtn.removeFromSuperview()
//            reviewCell.isHidden = true
            //            contentReview.super
//            reviewBtn.rem
//            tableView.estimatedRowHeight = 100;
//            tableView.rowHeight = UITableView.automaticDimension
//            reviewCell.heightAnchor
        }
    }
    
}
