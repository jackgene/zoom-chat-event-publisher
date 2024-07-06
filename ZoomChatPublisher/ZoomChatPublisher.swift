import AppKit
import RxCocoa
import RxSwift
import os

public struct ZoomChatPublisher {
    private let scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .default)
    private let urlSession: URLSession = URLSession.shared
    let destinationURL: URLComponents
    
    public init(destinationURL: URLComponents) {
        self.destinationURL = destinationURL
    }
    
    /// A single line of text in the Zoom chat window, which may be:
    /// - A route indicate the sender and recipient (e.g., "Me to Everyone", "Chatty Chad to Me")
    /// - The chat text
    private enum ZoomUIChatTextCell {
        case route(String)
        case text(String)
    }
    
    private func zoomApplication() -> AXUIElement? {
        (
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "us.zoom.xos")
                .first?
                .processIdentifier
        ).map(AXUIElementCreateApplication)
    }
    
    private func meetingWindow(app: AXUIElement) -> AXUIElement? {
        app.windows.first { $0.title == "Zoom Meeting" }
    }
    
    private func chatWindow(app: AXUIElement) -> AXUIElement? {
        app.windows.first {
            !($0.title ?? "").starts(with: "Zoom") && // "Zoom", "Zoom Meeting"
            $0.uiElements.contains {
                $0.role == kAXSplitGroupRole &&
                $0.uiElements.contains {
                    $0.role == kAXScrollAreaRole &&
                    $0.uiElements.contains {
                        $0.role == kAXTableRole
                    }
                }
            }
        }
    }
    
    private func anyMeetingWindow(app: AXUIElement) -> AXUIElement? {
        meetingWindow(app: app) ?? windowChatTable(app: app) ?? app.windows.first {
            $0.title?.starts(with: "zoom share") ?? false
        }
    }
    
    private func windowChatTable(app: AXUIElement) -> AXUIElement? {
        chatWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    private func embeddedChatTable(app: AXUIElement) -> AXUIElement? {
        meetingWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    // Due to how Zoom draws chats, this could be a chat table be in a mid-update state
    private func chatTableSnapshot(app: AXUIElement) -> AXUIElement? {
        windowChatTable(app: app) ?? embeddedChatTable(app: app)
    }
    
    // Returns the first two identical chatTableSnapshots
    private func chatTable(app: AXUIElement) -> Observable<AXUIElement?> {
        Observable<Int>
            .timer(.seconds(0), period: .milliseconds(2), scheduler: scheduler)
            .map { _ in chatTableSnapshot(app: app) }
            .scan(
                ("", "", nil)
            ) { (accum: (String, String, AXUIElement?), nextTable: AXUIElement?) in
                let (_, prevDescr, _): (String, String, AXUIElement?) = accum
                
                return (prevDescr, nextTable?.layoutDescription ?? "", nextTable)
            }
            .skip(1)
            .filter { (prevDescr: String, descr: String, table: AXUIElement?) in
                prevDescr == descr || table == nil
            }
            .map { (_, _, table: AXUIElement?) in table }
            .take(1)
    }
    
    private func chatTables(app: AXUIElement) -> Observable<AXUIElement?> {
        Observable<Int>
            .timer(.seconds(0), period: .milliseconds(500), scheduler: scheduler)
            .take(while: { _ in
                // meeting is ongoing
                anyMeetingWindow(app: app) != nil
            })
            .concatMap { _ in chatTable(app: app) }
    }
    
    private func chatRows(chatTables: Observable<AXUIElement?>) -> Observable<AXUIElement> {
        chatTables
            .scan((0, [])) { (accum: (Int, [AXUIElement]), table: AXUIElement?) in
                let (processedCount, _): (Int, _) = accum
                guard let table: AXUIElement = table else {
                    return (processedCount, [])
                }
                
                let newRows: [AXUIElement] = table.uiElements
                    .dropFirst(processedCount)
                    .reduce([]) { (accumRows: [AXUIElement], row: AXUIElement) in
                        // Rows with an x position of 0 seems to indicate a row before which all rows should be ignored?
                        row.uiElements.first?.position?.x == 0.0
                        ? [ row ]
                        : accumRows + [ row ]
                    }
                
                return (table.uiElements.count, newRows)
            }
            .concatMap { Observable.from($0.1) }
    }
    
    private func zoomUIChatTextFromRow(row: AXUIElement) -> [ZoomUIChatTextCell] {
        // Look in macOS system log to see what each row looks like
        // Note also that this may change with new versions of Zoom
        os_log("Chat rows layout:\n%{public}s", row.layoutDescription)
        
        // Information we are interested in:
        // - Routes ("Bob to Everyone", "You to Everyone", "Bob to You")
        // - Message text
        // We are not interested in:
        // - System announcements, e.g.,
        //   - "Bob has joined"
        //   - "Messages addressed to "Meeting Group Chat" will also appear in the
        //      meeting group chat in Team Chat"
        //
        // These have role=kAXUnknownRoles, and fixed heights of:
        // - Routes: 15.0
        // - System announcements: 13.0 per line
        // - Text:
        //   - Typically 16.0 per line
        //   - Text with Emoji are 21.0 per line
        //   - Emoji-only text are 39.0 per line
        // Note that 3-line system announcements and Emoji-only text are both
        // multiples of 39.0. However, route and text have dynamic widths no
        // wider than (row width - 140), whereas system announcement widths
        // typically exceed that.
        let routeHeight: CGFloat = 15.0
        let announcementLineHeight: CGFloat = 13.0
        let routeTextMinPadWidth: CGFloat = 140
        return row.uiElements.first?.uiElements
            .compactMap { (cell: AXUIElement) -> ZoomUIChatTextCell? in
                guard
                    cell.role == kAXUnknownRole,
                    let rowWidth: CGFloat = row.size?.width,
                    let cellWidth: CGFloat = cell.size?.width,
                    let cellHeight: CGFloat = cell.size?.height
                else {
                    return nil
                }
                
                if
                    cellHeight == announcementLineHeight || (
                        cellHeight.truncatingRemainder(
                            dividingBy: announcementLineHeight
                        ) == 0 &&
                        rowWidth - cellWidth < routeTextMinPadWidth
                    )
                {
                    return nil
                } else if cellHeight == routeHeight {
                    return cell.value.map { .route($0) }
                } else {
                    return cell.value.map { .text($0) }
                }
            } ?? []
    }
    
    public func scrapeAndPublishChatMessages() -> Observable<Result<PublishEvent, PublishError>> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(1), scheduler: scheduler)
            .map { _ -> Result<AXUIElement, PublishError> in
                guard let app = zoomApplication() else {
                    return .failure(.zoomNotRunning)
                }
                guard let _ = anyMeetingWindow(app: app) else {
                    return .failure(.noMeetingInProgress)
                }
                
                return .success(app)
            }
            .flatMapFirst { (appResult: Result<AXUIElement, PublishError>) in
                switch appResult {
                case .success(let app):
                    let chatTables: Observable<AXUIElement?> = chatTables(app: app).share()
                    let metadata: Observable<Result<PublishEvent, PublishError>> = chatTables
                        .map {
                            $0 != nil ? .success(.noOp) : .failure(.chatNotOpen)
                        }
                    let publishes: Observable<Result<PublishEvent, PublishError>> = chatRows(chatTables: chatTables)
                        .map { row -> Result<AXUIElement, PublishError> in .success(row) }
                        .concatMap {
                            (
                                rowResult: Result<AXUIElement, PublishError>
                            ) -> Observable<Result<ZoomUIChatTextCell, PublishError>>
                            in
                            
                            switch rowResult {
                            case .success(let row):
                                return Observable
                                    .from(zoomUIChatTextFromRow(row: row))
                                    .map { .success($0) }
                                
                            case .failure(let error):
                                return Observable.just(.failure(error))
                            }
                        }
                        .scan(
                            ("Unknown to Unknown", nil)
                        ) { (
                            accum: (String, Result<ChatMessage, PublishError>?),
                            nextCellResult: Result<ZoomUIChatTextCell, PublishError>
                        ) in
                            let (route, _): (String, _) = accum
                            switch nextCellResult {
                            case .success(let nextCell):
                                switch nextCell {
                                case .route(let nextRoute):
                                    return (nextRoute, nil)
                                case .text(let text):
                                    return (route, .success(ChatMessage(route: route, text: text)))
                                }
                                
                            case .failure(let error):
                                return (route, .failure(error))
                            }
                        }
                        .compactMap { $0.1 }
                        .concatMap { (
                            chatMessageResult: Result<ChatMessage, PublishError>
                        ) -> Observable<Result<PublishEvent, PublishError>> in
                            switch chatMessageResult {
                            case .success(let chatMessage):
                                var urlComps: URLComponents = destinationURL
                                urlComps.queryItems = [
                                    URLQueryItem(name: "route", value: chatMessage.route),
                                    URLQueryItem(name: "text", value: chatMessage.text)
                                ]
                                guard let url = urlComps.url else {
                                    return Observable.never()
                                }
                                var urlRequest: URLRequest = URLRequest(url: url)
                                urlRequest.httpMethod = "POST"
                                
                                return urlSession.rx.response(request: urlRequest)
                                    .map { .success($0.response) }
                                    .retry { (errors: Observable<Error>) in
                                        // Retry with delay, inspired by:
                                        // https://github.com/ReactiveX/RxSwift/issues/689#issuecomment-595117647
                                        let maxAttempts: Int = 3
                                        let delay: DispatchTimeInterval = .seconds(2)
                                        
                                        return errors.enumerated()
                                            .flatMap { (index: Int, error: Error) -> Observable<Int> in
                                                index <= maxAttempts
                                                ? Observable<Int>.timer(delay, scheduler: scheduler)
                                                : Observable.error(error)
                                            }
                                    }
                                    .catch { Observable.just(.failure($0)) }
                                    .map {
                                        .success(
                                            .publish(
                                                attempt: PublishAttempt(
                                                    chatMessage: chatMessage, httpResponseResult: $0
                                                )
                                            )
                                        )
                                    }
                                
                            case .failure(let error):
                                return Observable.just(.failure(error))
                            }
                        }
                    return Observable.of(metadata, publishes).merge()
                    
                case .failure(let error):
                    return Observable.just(.failure(error))
                }
            }
            .do(
                onCompleted: { os_log("Terminated (should not happen)", type: .fault) }
            )
    }
}
