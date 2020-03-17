//
//  MovieDetailsTableViewController.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 2/27/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import SDWebImage
import youtube_ios_player_helper
import Cosmos
class MovieDetailsTableViewController: UITableViewController {
    var isFavourite = false
    @IBAction func favouriteBtnTuched(_ sender: Any) {
        if isFavourite == false
        {
            let savePresenter = SaveMovieFavouritePresenter(saveFavouriteRef: self)
            savePresenter.saveFavuriteMovies(movieObj: movieObj)
            
        }
        else{
            let removePresenter = RemoveMovieFavouritePresenter(removeFavouriteRef: self)
            removePresenter.removeFavuriteMovies(movieID: movieObj.id)
        }
    }

    @IBOutlet var widthConstrain: NSLayoutConstraint!
    @IBOutlet var heightConstrain: NSLayoutConstraint!
    @IBOutlet weak var favouriteBtn: UIButton!
    @IBOutlet var reviewBtn: UIButton!
    @IBOutlet var movieImage: UIImageView!
    @IBOutlet var movieNameLbl: UILabel!
    @IBOutlet var movieYearLbl: UILabel!
    @IBOutlet var movieOverView: UILabel!
    @IBOutlet var cosmosView: CosmosView!
    @IBOutlet var reviewCell: UITableViewCell!

    @IBOutlet var trailerCollectionView: UICollectionView!
    @IBOutlet var genreCollectionView: UICollectionView!
    @IBOutlet var contentReview: UILabel!
    @IBOutlet var authorNameReview: UILabel!
    
    @IBAction func showAllReviewsBtn(_ sender: Any) {
        var allReview : MovieAllReviewsTableViewController = self.storyboard?.instantiateViewController(withIdentifier: "MovieAllReviews") as! MovieAllReviewsTableViewController
       
        allReview.movieReviewList = movieReviewList
        self.navigationController?.pushViewController(allReview, animated: true)
    }
    var widthTrailer : CGFloat!
    var heightTrailer : CGFloat!
    var movieReviewList = [MovieReview]()
    var movieObj : Movie!
    var movieTrailerList = [MovieTrailer]()
    override func viewWillAppear(_ animated: Bool) {
        let checkPresenter = CheckMovieFavouritePresenter(checkFavouriteRef : self)
        checkPresenter.checkFavuriteMovies(movieID : movieObj.id)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
//        authorNameReview.text = "There is no reviews to show"
//
//        contentReview.removeFromSuperview()
//        reviewBtn.removeFromSuperview()
        self.title = movieObj.title
        var movieDetailObj = MovieTrailerPresenter(movieDetailRef: self)
        movieDetailObj.getMovieTrailers(movieId: movieObj.id)
        var movieDetailReviewObj = MovieReviewPresenter(movieDetailRef: self)
        movieDetailReviewObj.getMovieReview(movieId: movieObj.id)
        cosmosView.settings.updateOnTouch = false
        cosmosView.settings.fillMode = .precise
        cosmosView.rating = Double(movieObj.rating / 2)
        cosmosView.settings.filledColor = UIColor.orange
        cosmosView.settings.emptyBorderColor = UIColor.orange
        cosmosView.settings.filledBorderColor = UIColor.orange
        movieImage.sd_setImage(with: URL(string: "https://image.tmdb.org/t/p/w185" + movieObj.image), placeholderImage: UIImage(named: "placeholder.png"))
        movieNameLbl.text = movieObj.title
        movieYearLbl.text = movieObj.releaseDate
        movieOverView.text = movieObj.overview
        tableView.estimatedRowHeight = 100;
        tableView.rowHeight = UITableView.automaticDimension
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        if indexPath.row == 0
        {

//            let pixelWidth = UIScreen.main.nativeBounds.width
//            let pixelHeight = UIScreen.main.nativeBounds.height
//            let pointWidth = pixelWidth / UIScreen.main.nativeScale
//            let pointHeight = pixelHeight / UIScreen.main.nativeScale
            let pastWidth = UIScreen.main.nativeBounds.width
            let portraitWidth = pastWidth / UIScreen.main.nativeScale
            widthTrailer = tableView.frame.size.width
            let pastHeight = CGFloat(232)
            heightTrailer = (pastHeight * widthTrailer) / portraitWidth
            let x = Int(widthTrailer!)
//            let y = Int(heightTrailer)
            let y = Int(heightTrailer!)
                       
            widthConstrain.constant = CGFloat(x)
//            heightConstrain.constant = CGFloat(y)
//            trailerCollectionView.layoutIfNeeded()
//            trailerCollectionView.reloadData()
//            for constraint in trailerCollectionView.constraints {
//                if constraint.identifier == "trailerWidthConstrain" {
//                   constraint.constant = width
//                }
//                if constraint.identifier == "trailerHeightConstrain" {
//                   constraint.constant = height
//                }
//            }
            
//            trailerCollectionView.layoutIfNeeded()
            trailerCollectionView.updateConstraints()
            trailerCollectionView.reloadData()

            return 232
        }
        else if indexPath.row == 1
        {
            return 125
        }
        else if indexPath.row == 2
        {
            return 248
        }
        else if indexPath.row == 3
        {
            return 65
        }
        else if indexPath.row == 4
        {
            return 200
        }
        else
        {
            if movieReviewList.count > 0 {
                return 273
            }
            else{
                return 150
            }
        }
    }
}


