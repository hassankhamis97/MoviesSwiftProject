//
//  MainMovieCollectionViewCell.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/23/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import Cosmos
class MainMovieCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var movieImgView: UIImageView!
    
    @IBOutlet weak var favouriteBtn: UIButton!
    @IBOutlet var rating: UIButton!
    
    
    @IBOutlet weak var movieNameLbl: UILabel!
        
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//
//        let height = collectionView.frame.size.height
//        let width = collectionView.frame.size.width
//        // in case you you want the cell to be 40% of your controllers view
//        return CGSize(width: width * 0.5, height: height * 0.5)
//    }
}
