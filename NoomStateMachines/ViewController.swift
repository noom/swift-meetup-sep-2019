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

fileprivate let cellIdentifier = "cell"
fileprivate let infiniteScrollTreshold = CGFloat(75)

class ViewController: UIViewController {
    fileprivate let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
    fileprivate let tableView = UITableView(frame: .zero)
    fileprivate let service: ArticleService
    
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
    
    init(service: ArticleService) {
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
        
        let tableView = self.tableView
        let loaderView = self.loaderView
        
        self.navigationItem.rightBarButtonItem = self.refreshButton
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        let state = PagingState.system(
            service: self.service,
            loadMore: tableView.rx.contentOffset
                .map { (contentOffset: CGPoint) -> Bool in
                    let offsetFromBottom = tableView.contentSize.height - tableView.bounds.height - contentOffset.y
                    return offsetFromBottom < infiniteScrollTreshold
                }
                .distinctUntilChanged()
                .filter { $0 }
                .map { _ in },
            refresh: self.refreshButton.rx.tap.asObservable()
        )
        
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

extension Article: IdentifiableType {
    typealias Identity = UUID
    var identity: UUID { return self.id }
}
typealias SectionModel = AnimatableSectionModel<String, Article>
