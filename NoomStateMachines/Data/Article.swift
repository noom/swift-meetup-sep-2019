//
//  Article.swift
//  NoomStateMachines
//
//  Created by Ivan on 03/09/2019.
//  Copyright © 2019 Noom Inc. All rights reserved.
//

import Foundation

struct Article: Equatable {
    let id: UUID
    let author: String
    let url: URL
    let date: Date
    let title: String
    let body: String
}
