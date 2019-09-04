//
//  ViewController.swift
//  NoomStateMachines
//
//  Created by Ivan on 03/09/2019.
//  Copyright © 2019 Noom Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import RxFeedback
import RxDataSources
import SnapKit

fileprivate struct State {
    var allArticles: [Article] = []
    
    var pageSize: Int = 20
    var isLoading: Bool = true
    var canLoadMore: Bool = true
}

fileprivate let cellIdentifier = "cell"
fileprivate let infiniteScrollTreshold = CGFloat(75)

class ViewController: UIViewController {
    fileprivate let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
    fileprivate let tableView = UITableView(frame: .zero)
    fileprivate let service: Service
    
    fileprivate let dataSource: RxTableViewSectionedAnimatedDataSource<SectionModel>
    fileprivate let disposeBag = DisposeBag()
    
    fileprivate lazy var loaderView: UIView = {
        let view = UIView(frame: .zero)
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { $0.center.equalToSuperview() }
        return view
    }()
    
    init(service: Service) {
        self.service = service
        self.dataSource = RxTableViewSectionedAnimatedDataSource<SectionModel>(configureCell: { (ds, tv, ip, item) -> UITableViewCell in
            let cell = tv.dequeueReusableCell(withIdentifier: cellIdentifier, for: ip)
            cell.textLabel?.text = item.title
            return cell
        })
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let service = self.service
        let refreshButton = self.refreshButton
        let tableView = self.tableView
        let loaderView = self.loaderView
        
        self.navigationItem.rightBarButtonItem = self.refreshButton
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        let infiniteScrollFeedback: Feedback = react(
            request: { $0.canInfiniteScroll },
            effects: { (_: Bool) -> Observable<Event> in
                return tableView.rx.contentOffset
                    .map { (contentOffset: CGPoint) -> Bool in
                        let offsetFromBottom = tableView.contentSize.height - tableView.bounds.height - contentOffset.y
                        return offsetFromBottom < infiniteScrollTreshold
                    }
                    .distinctUntilChanged()
                    .filter { $0 }
                    .map { _ in Event.loadMore }
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
            return refreshButton.rx.tap.map { Event.reload }
        }
        
        let state = Observable
            .system(
                initialState: State(),
                reduce: State.reduce,
                scheduler: MainScheduler.asyncInstance,
                feedback: [loadArticlesFeedback, infiniteScrollFeedback, refreshFeedback]
            )
            .share(replay: 1, scope: .whileConnected)
        
        state
            .map { [SectionModel(model: "section", items: $0.allArticles)] }
            .bind(to: self.tableView.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
        
        state
            .map { $0.canLoadMore }
            .distinctUntilChanged()
            .subscribe(onNext: { (canLoadMore: Bool) in
                guard canLoadMore else { tableView.tableFooterView = nil; return }
                loaderView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: infiniteScrollTreshold)
                tableView.tableFooterView = loaderView
            })
            .disposed(by: self.disposeBag)
    }
}

fileprivate enum Event {
    case loadMore
    case loaded([Article])
    case reload
}

fileprivate typealias Feedback = (ObservableSchedulerContext<State>) -> Observable<Event>

extension State {
    static func reduce(state: State, event: Event) -> State {
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

extension Article: IdentifiableType {
    typealias Identity = UUID
    var identity: UUID { return self.id }
}
typealias SectionModel = AnimatableSectionModel<String, Article>
