//
//  File.swift
//  MoviesProject
//
//  Created by Hassan Khamis on 2/24/20.
//  Copyright © 2020 Hassan Khamis. All rights reserved.
//

import Foundation
protocol IBase {
    func showLoad()
    func hideLoad()
    func showErrorMsg(errMsg : String)
}
