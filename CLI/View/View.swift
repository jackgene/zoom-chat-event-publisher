import RxSwift
import ZoomChatPublisher

/// View renderer operations
protocol View {
    func render(_ events: Observable<Result<PublishEvent, PublishError>>) -> Disposable
}
