//
//  Service.swift
//  NoomStateMachines
//
//  Created by Ivan on 03/09/2019.
//  Copyright © 2019 Noom Inc. All rights reserved.
//

import Foundation
import RxSwift
import SwiftyJSON
import SwiftDate

class Service {
    var data: [Article]
    
    init() {
        guard let url = Bundle.main.url(forResource: "articles", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let json = try? JSON(data: data)
            else { fatalError("No data") }
        
        self.data = json.arrayValue.map(Article.init(json:))
    }
    
    func get(from id: UUID?, limit: Int) -> Single<[Article]> {
        return Single
            .deferred {
                guard let id = id, let startIndex = self.data.firstIndex(where: { $0.id == id })
                    else { return Single.just(Array(self.data[0..<limit])) }
                let endIndex = min(startIndex + 1 + limit, self.data.count)
                return Single.just(Array(self.data[startIndex + 1..<endIndex]))
            }
            // Simulate network call delay
            .delay(.seconds(1), scheduler: MainScheduler.instance)
    }
}

fileprivate extension Article {
    init(json: JSON) {
        self.id = UUID(uuidString: json["id"].stringValue)!
        self.author = json["author"].stringValue
        self.url = URL(string: json["url"].stringValue)!
        self.date = Date(json["date"].stringValue)!
        self.title = json["title"].stringValue
        self.body = json["body"].stringValue
    }
}
