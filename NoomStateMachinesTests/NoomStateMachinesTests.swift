//
//  NoomStateMachinesTests.swift
//  NoomStateMachinesTests
//
//  Created by Ivan on 05/09/2019.
//  Copyright © 2019 Noom Inc. All rights reserved.
//

import XCTest
import RxSwift
import RxFeedback
import RxTest

class NoomStateMachinesTests: XCTestCase {
    var scheduler: TestScheduler!
    let service = LocalDataArticleService(simulateDelay: false)
    
    override func setUp() {
        self.scheduler = TestScheduler(initialClock: 0)
    }
    
    func testStateMachineWorks() {
        let state = PagingState.system(
            service: self.service,
            loadMore: self.scheduler.createHotObservable([.next(300, ()), .next(320, ()), .next(350, ())]).asObservable(),
            refresh: self.scheduler.createHotObservable([.next(340, ())]).asObservable(),
            scheduler: self.scheduler
        )
        
        let result = self.scheduler.start { state }
        let states = result.events.compactMap { $0.value.element }
        XCTAssertEqual(states, [
            // Initial state
            PagingState(),
            // Load triggered by initial state
            PagingState(allArticles: Array(self.service.data[0..<20]), pageSize: 20, isLoading: false, canLoadMore: true),
            // Load more at 300
            PagingState(allArticles: Array(self.service.data[0..<20]), pageSize: 20, isLoading: true, canLoadMore: true),
            // Loaded
            PagingState(allArticles: Array(self.service.data[0..<40]), pageSize: 20, isLoading: false, canLoadMore: true),
            // Load more at 320
            PagingState(allArticles: Array(self.service.data[0..<40]), pageSize: 20, isLoading: true, canLoadMore: true),
            // Loaded
            PagingState(allArticles: Array(self.service.data[0..<60]), pageSize: 20, isLoading: false, canLoadMore: true),
            // Refresh at 340
            PagingState(),
            // Load triggered by refresh
            PagingState(allArticles: Array(self.service.data[0..<20]), pageSize: 20, isLoading: false, canLoadMore: true),
            // Refresh at 350
            PagingState(allArticles: Array(self.service.data[0..<20]), pageSize: 20, isLoading: true, canLoadMore: true),
            // Loaded
            PagingState(allArticles: Array(self.service.data[0..<40]), pageSize: 20, isLoading: false, canLoadMore: true)
            ])
    }
}
