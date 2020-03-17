//
//  FavouriteTableViewController.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import Alamofire
class FavouriteTableViewController: UITableViewController {
    var movieList = [Movie]()
    var errMsg : String = ""
    var genrePrint : String?;

    override func viewWillAppear(_ animated: Bool) {
        var getFavo = GetFavouritePresenter(getFavouriteRef: self)
        getFavo.getFavuriteMovies()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
//        var getFavo = GetFavouritePresenter(getFavouriteRef: self)
//        getFavo.getFavuriteMovies()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
//        return 0
        var numOfSections: Int = 0
        if movieList.count > 0
        {
            tableView.separatorStyle = .singleLine
            numOfSections = 1
            tableView.backgroundView = nil
        }
        else
        {
            
            let noDataLabel: UILabel  = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
            noDataLabel.text          = errMsg
//            noDataLabel.textColor     = UIColor.black
            noDataLabel.textAlignment = .center
            tableView.backgroundView  = noDataLabel
            tableView.separatorStyle  = .none
        }
        return numOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return movieList.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : FavouriteTableViewCell = tableView.dequeueReusableCell(withIdentifier: "favouriteCell", for: indexPath) as! FavouriteTableViewCell
        cell.movieTitleLbl.text = movieList[indexPath.row].title
        cell.cosmosRating.settings.updateOnTouch = false
        cell.cosmosRating.settings.fillMode = .precise
        cell.cosmosRating.rating = Double(movieList[indexPath.row].rating / 2)
        cell.cosmosRating.settings.filledColor = UIColor.orange
        cell.cosmosRating.settings.emptyBorderColor = UIColor.orange
        cell.cosmosRating.settings.filledBorderColor = UIColor.orange

        cell.movieImg.sd_setImage(with: URL(string: "https://image.tmdb.org/t/p/w185" + movieList[indexPath.row].image), placeholderImage: UIImage(named: "placeholder.png"))
        
        var count = 1
        for item in movieList[indexPath.row].genreName {
            if count == 1 {
                genrePrint = item
            }
            else
            {
                genrePrint!.append(" - \(item)")
            }
            count += 1;
        }
        cell.movieDetailsLbl.text = genrePrint

        return cell
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        return 114
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var mdCon = self.storyboard?.instantiateViewController(withIdentifier: "movieDetailsStoryBoard") as! MovieDetailsTableViewController
        
        mdCon.movieObj = movieList[indexPath.row]
        self.navigationController?.pushViewController(mdCon, animated: true)
    }
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let removePresenter = RemoveMovieFavouritePresenter(removeFavouriteRef: self)
            var movId = movieList[indexPath.row].id!
            movieList.remove(at: indexPath.row)
            removePresenter.removeFavuriteMovies(movieID: movId)
            tableView.reloadData()
            
        }
    }
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
