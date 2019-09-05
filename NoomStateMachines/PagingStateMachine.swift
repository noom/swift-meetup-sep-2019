//
//  PagingStateMachine.swift
//  NoomStateMachines
//
//  Created by Ivan on 05/09/2019.
//  Copyright © 2019 Noom Inc. All rights reserved.
//

import Foundation
import RxSwift
import RxFeedback

struct PagingState: Equatable {
    var allArticles: [Article] = []
    
    var pageSize: Int = 20
    var isLoading: Bool = true
    var canLoadMore: Bool = true
}

extension PagingState {
    static func system(service: ArticleService,
                loadMore: Observable<()>,
                refresh: Observable<()>,
                scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance
        ) -> Observable<PagingState> {
        let infiniteScrollFeedback: Feedback = react(
            request: { $0.canInfiniteScroll },
            effects: { (_: Bool) -> Observable<Event> in
                return loadMore.map { _ in Event.loadMore }
            }
        )
        
        let loadArticlesFeedback: Feedback = react(
            request: { $0.canLoadArticles },
            effects: { (request: LoadArticlesRequest) -> Observable<Event> in
                return service
                    .get(from: request.from, limit: request.limit)
                    .map { .loaded($0) }
                    .asObservable()
            }
        )
        
        let refreshFeedback: Feedback = { _ in
            return refresh.map { Event.reload }
        }
        
        return Observable
            .system(
                initialState: PagingState(),
                reduce: PagingState.reduce,
                scheduler: scheduler,
                feedback: [loadArticlesFeedback, infiniteScrollFeedback, refreshFeedback]
            )
            .share(replay: 1, scope: .whileConnected)
    }
}

fileprivate enum Event {
    case loadMore
    case loaded([Article])
    case reload
}

fileprivate typealias Feedback = (ObservableSchedulerContext<PagingState>) -> Observable<Event>

fileprivate extension PagingState {
    static func reduce(state: PagingState, event: Event) -> PagingState {
        var newState = state
        switch event {
        case .loadMore:
            if newState.canLoadMore {
                newState.isLoading = true
            }
        case .loaded(let articles):
            newState.allArticles.append(contentsOf: articles)
            newState.isLoading = false
            newState.canLoadMore = articles.count >= newState.pageSize
        case .reload:
            newState.allArticles = []
            newState.isLoading = true
            newState.canLoadMore = true
        }
        return newState
    }
    
    var canLoadArticles: LoadArticlesRequest? {
        if self.isLoading {
            return LoadArticlesRequest(
                from: self.allArticles.last?.id,
                limit: self.pageSize
            )
        }
        return nil
    }
    
    var canInfiniteScroll: Bool? {
        if self.canLoadMore {
            return true
        }
        return nil
    }
}

fileprivate struct LoadArticlesRequest: Equatable {
    let from: UUID?
    let limit: Int
}
