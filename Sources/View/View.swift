import RxSwift

/// View renderer operations
protocol View {
    func render(_ events: Observable<Result<PublishEvent, PublishError>>) -> Disposable
}
