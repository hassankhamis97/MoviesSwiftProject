//
//  MainPresenter.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/24/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import Reachability
class MainPresenter : IMainPresenter {
    
    var mainRef : IMainView!
    init(mainRef : IMainView) {
        self.mainRef = mainRef
    }
    func getMovies(sortOption: String){
        let reachability = try! Reachability()
        mainRef.showLoad()
        reachability.whenReachable = { reachability in
            self.mainRef.networkStatus(isOnline: true)
            let mainModel = MainModel(presenterRef: self)
            mainModel.getMovies(sortOption: sortOption)
            reachability.stopNotifier()
        }
        reachability.whenUnreachable = { _ in
            self.mainRef.networkStatus(isOnline: false)
            let mainModel = MainModel(presenterRef: self)
            mainModel.getMoviesFromCoreData(sortOption: sortOption)
            print("Not reachable")
            reachability.stopNotifier()
        }

        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
        
    }
    
    func onSuccess(movieList: [Movie]) {
        mainRef.hideLoad()
        mainRef.renderMoviesForUser(movieList: movieList)
    }
    
    func onFail(errMsg: String) {
        mainRef.hideLoad()
        mainRef.showErrorMsg(errMsg: errMsg)
    }
    
}
