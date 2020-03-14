//
//  MovieDetailsCollectionViewExtensions.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
import UIKit
extension MovieDetailsTableViewController : UICollectionViewDelegate,UICollectionViewDataSource
{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(collectionView == trailerCollectionView)
        {
            return movieTrailerList.count;
        }
        return movieObj.genreName.count
        
    }
    

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if(collectionView == genreCollectionView)
        {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "genreCollectionCell", for: indexPath) as! GenreCollectionViewCell
            cell.genreNameLbl.text = movieObj.genreName[indexPath.row]
            cell.genreNameLbl.layer.borderColor = UIColor.darkGray.cgColor
            cell.genreNameLbl.layer.borderWidth = 3.0
            cell.genreNameLbl.textColor = getGenreColor(name: movieObj.genreName[indexPath.row])
            cell.genreNameLbl.layer.cornerRadius = 10
            return cell
        }
        else{
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TrailerCollectionCell", for: indexPath) as! MovieTrailerCollectionViewCell
        
            // Configure the cell
        cell.movieTrailerYoutube.load(withVideoId: movieTrailerList[indexPath.row].key)
        
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
//        flowLayout.estimatedItemSize = CGSize(width: 414 , height: 231)
            flowLayout.estimatedItemSize = trailerCollectionView.layer.preferredFrameSize()
            flowLayout.minimumInteritemSpacing = 0;
            flowLayout.minimumLineSpacing = 0;
        }
            
        
        
            return cell
        
        }
    }
    func getGenreColor(name: String) -> UIColor {
        switch name {
        case "Action":
            return UIColor.blue
        case "Comedy","Animation":
            return UIColor.yellow
        case "Adventure":
            return UIColor.green
            case "Crime","Gangster":
            return UIColor.purple
            case "Drama" , "Romance":
            return UIColor.red
            case "History":
            return UIColor.systemYellow
            case "Horror":
            return UIColor.darkGray
            case "Music":
            return UIColor.orange
            case "Science Fiction":
            return UIColor.init(red: 0, green: 192, blue: 192, alpha: 1)
            case "War":
            return UIColor.systemIndigo
            case "Western":
            return UIColor.brown
            
        default:
            return UIColor.init(red: 255, green: 255, blue: 255, alpha: 1)
        }
    }
}
