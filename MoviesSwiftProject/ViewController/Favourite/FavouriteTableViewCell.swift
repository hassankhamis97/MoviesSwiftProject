//
//  FavouriteTableViewCell.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/7/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit
import Cosmos
class FavouriteTableViewCell: UITableViewCell {

    @IBOutlet var cosmosRating: CosmosView!
    @IBOutlet weak var movieImg: UIImageView!
    @IBOutlet weak var movieTitleLbl: UILabel!
    @IBOutlet weak var movieDetailsLbl: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
