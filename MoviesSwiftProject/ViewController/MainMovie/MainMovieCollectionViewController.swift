//
//  MainMovieCollectionViewController.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/23/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import SDWebImage
import Cosmos
import DropDown
private let reuseIdentifier = "mainCell"

class MainMovieCollectionViewController: UICollectionViewController ,UICollectionViewDelegateFlowLayout{
    let dropDown = DropDown()
    var mainPresenter : MainPresenter!


    
    @IBOutlet var sortButtonBar: UIBarButtonItem!
    @IBAction func sortButton(_ sender: Any) {
        
        dropDown.show()
    }
    var movieList = [Movie]()
    var errMsg : String = ""
    var isDataLoaded = false
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        dropDown.anchorView = sortButtonBar
        dropDown.selectRow(at: 1)
        dropDown.dataSource = ["Popularity", "Top Rated", "Now Playing","Upcoming","Date"]
        dropDown.width = 200
//        dropDown.
//        dropDownLeft.width = 200
        dropDown.direction = .any
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            if item == "Popularity"
            {
                self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/discover/movie?api_key=6557d01ac95a807a036e5e9e325bb3f0&sort_by=popularity.desc")
            }
            
            else if item == "Top Rated"
            {
                self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/movie/top_rated?api_key=6557d01ac95a807a036e5e9e325bb3f0")
            }
            else if item == "Now Playing"
            {
                self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/movie/now_playing?api_key=6557d01ac95a807a036e5e9e325bb3f0")
            }
            else if item == "Upcoming"
            {
                self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/movie/upcoming?api_key=6557d01ac95a807a036e5e9e325bb3f0")
            }
            else if item == "Date"
            {
                self.mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/discover/movie?api_key=6557d01ac95a807a036e5e9e325bb3f0&sort_by=primary_release_date.desc")
            }
        }
//        dropDown.topOffset = CGPoint.init(x: 20, y: 20)
        
        
//        var modelObj = MovieDetailsModel(moviePresenterRef: self)
//        modelObj.getMovieReviews(movieID: 419704)
        mainPresenter = MainPresenter(mainRef: self)
        mainPresenter.getMovies(sortOption: "https://api.themoviedb.org/3/discover/movie?api_key=6557d01ac95a807a036e5e9e325bb3f0&sort_by=popularity.desc")
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
//        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
//self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        // Do any additional setup after loading the view.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        var numOfSections: Int = 0
            if movieList.count > 0
            {
//                collectionView.separatorStyle = .singleLine
                numOfSections            = 1
                collectionView.backgroundView = nil
            }
            else
            {
                
                let noDataLabel: UILabel  = UILabel(frame: CGRect(x: 0, y: 0, width: collectionView.bounds.size.width, height: collectionView.bounds.size.height))
                noDataLabel.text          = errMsg
                noDataLabel.textAlignment = .center
                collectionView.backgroundView  = noDataLabel
            }
        return numOfSections
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        
        return movieList.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        var cell : MainMovieCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! MainMovieCollectionViewCell
        //cell.movieNameLbl.text = movieList[indexPath.row].title
        //cell.movieImgView.sd_imageIndicator = SDWebImageActivityIndicator.gray
        cell.movieImgView.sd_setShowActivityIndicatorView(true)
        
        cell.movieImgView.sd_setIndicatorStyle(.large)
        cell.movieImgView.sd_setIndicatorStyle(.white)

        
        cell.movieImgView.sd_setImage(with: URL(string: "https://image.tmdb.org/t/p/w185" + movieList[indexPath.row].image), placeholderImage: UIImage(named: "placeholder.png"))
        
//        cell.rating.titleLabel?.text = String(movieList[indexPath.row].rating!)
        cell.rating.setTitle(String(movieList[indexPath.row].rating!), for: UIControl.State.init())
        
//        cell.movieImgView.sd_setImage(with: URL(string: "https://image.tmdb.org/t/p/w185/xBHvZcjRiWyobQ9kxBhO6B2dtRI.jpg"), placeholderImage: UIImage(named: "placeholder.png"))
//        print("http://image.tmdb.org/t/p/w185" + movieList[indexPath.row].image)
        
//        cosmosView.settings.starPoints = [CGPoint(x: 16, y: 118)]
//        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
//            flowLayout.minimumInteritemSpacing = 0;
//            flowLayout.minimumLineSpacing = 0;
////            let height = collectionView.frame.size.height
////            let width = collectionView.frame.size.width
////            flowLayout.estimatedItemSize = CGSize(width: width * 0.45, height: height)
//        }
        
        
        return cell
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var mdCon = self.storyboard?.instantiateViewController(withIdentifier: "movieDetailsStoryBoard") as! MovieDetailsTableViewController
        
        mdCon.movieObj = movieList[indexPath.row]
        self.navigationController?.pushViewController(mdCon, animated: true)
    }
   func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//       let width = ((collectionView.frame.width - 20) / 2) // 15 because of paddings
//       print("cell width : \(width)")
//       return CGSize(width: width, height: 200)
    let height = collectionView.frame.size.height
    let width = collectionView.frame.size.width
    
    if(height > width)
    {
    // in case you you want the cell to be 40% of your controllers view
//        return CGSize(width: width * 0.5, height: 266)
        let cellHeight = (width * 0.5 * 285)/(375 * 0.5)
        return CGSize(width: width * 0.5, height: cellHeight)
    }
    else{
        let cellHeight = (width * 0.25 * 250)/(667 * 0.25)
        return CGSize(width: width * 0.25, height: cellHeight)
    }
   }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0;
    }
//    override func viewDidLayoutSubviews() {
//            collectionView.collectionViewLayout.invalidateLayout()
//
//    }
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
//        return UIEdgeInsets(top: 0,left: 0,bottom: 0,right: 0)
//    }
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
//    {
//        return CGSize(width: 173.0, height: 228.0)
//    }
    
//    func collectionView(collectionView: UICollectionView , layout:(UICollectionViewLayout )collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath) -> CGSize
//    {
//        return CGSizeMake(200, 200);
//    }
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
//    {
//            // In this function is the code you must implement to your code project if you want to change size of Collection view
//
//        return CGSize(width: 173.0, height: 228.0)
//    }
    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
