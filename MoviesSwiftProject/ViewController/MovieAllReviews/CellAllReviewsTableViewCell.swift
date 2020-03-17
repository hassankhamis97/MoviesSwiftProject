//
//  CellAllReviewsTableViewCell.swift
//  MoviesSwiftProject
//
//  Created by Hassan Khamis on 3/6/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import UIKit

class CellAllReviewsTableViewCell: UITableViewCell {
    @IBOutlet var authorName: UILabel!
    @IBOutlet var contentReview: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    

}
