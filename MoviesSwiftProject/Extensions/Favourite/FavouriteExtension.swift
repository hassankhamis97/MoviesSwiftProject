//
//  FavouriteExtension.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
extension FavouriteTableViewController : IGetFavouriteView
{
    func renderMoviesForUser(movieList: [Movie]) {
        self.movieList = movieList
        self.tableView.reloadData()
    }
    
    func showLoad() {
    }
    
    func hideLoad() {
    }
    
    func showErrorMsg(errMsg: String) {
        self.errMsg = errMsg
        self.movieList = [Movie]()
        self.tableView.reloadData()

//        tableView.backgroundView = errView
//        errMsgLbl.text = errMsg
    }
    
    
}
