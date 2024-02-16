import Curses
import Foundation
import RxSwift

private let intervalFormatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.unitsStyle = .full
    f.allowedUnits = [.month, .day, .hour, .minute, .second]
    f.maximumUnitCount = 3
    
    return f
}()

struct CursesView<TerminalSizes: Observable<Size>>: View {
    private let screen: Screen
    private let mainWindow: Window
    private let consoleWindow: Window
    private let statusOkAttribute: Attribute
    private let statusBadAttribute: Attribute
    private let successAttribute: Attribute
    private let failureAttribute: Attribute
    private let metadataAttribute: Attribute
    private let terminalSizes: TerminalSizes
    
    init(
        screen: Screen,
        statusOkAttribute: Attribute, statusBadAttribute: Attribute,
        successAttribute: Attribute, failureAttribute: Attribute,
        metadataAttribute: Attribute, terminalSizes: TerminalSizes
    ) {
        self.screen = screen
        self.mainWindow = screen.window
        self.consoleWindow = screen.newWindow(
            position: Point(x: 0, y: 1), size: Size(width: 0, height: 0)
        )
        self.consoleWindow.setScroll(enabled: true)
        self.statusOkAttribute = statusOkAttribute
        self.statusBadAttribute = statusBadAttribute
        self.successAttribute = successAttribute
        self.failureAttribute = failureAttribute
        self.metadataAttribute = metadataAttribute
        self.terminalSizes = terminalSizes
    }
    
    private func pad(_ text: String, maxWidth: Int) -> String {
        let textWidth: Int = text.count
        
        if textWidth == maxWidth {
            return text
        } else if textWidth > maxWidth {
            return String(text.prefix(maxWidth))
        } else {
            let paddingSize: Int = maxWidth - textWidth
            let prePaddingSize: Int = paddingSize / 2
            let postPaddingsize: Int = paddingSize - prePaddingSize
            
            return String(
                repeating: " ", count: prePaddingSize
            ) + text + String(
                repeating: " ", count: postPaddingsize
            )
        }
    }
    
    private func writeZoomRunningStatus(ok: Bool, width: Int) {
        mainWindow.cursor.position = Point(x: 0, y: 0)
        if ok {
            mainWindow.write(
                pad("Zoom Is Running", maxWidth: width), attribute: statusOkAttribute
            )
        } else {
            mainWindow.write(
                pad("Zoom Not Running", maxWidth: width), attribute: statusBadAttribute
            )
        }
    }
    
    private func writeMeetingOngoingStatus(ok: Bool?, width: Int) {
        mainWindow.cursor.position = Point(x: width + 1, y: 0)
        switch ok {
        case .some(true):
            mainWindow.write(
                pad("Meeting In Progress", maxWidth: width),
                attribute: statusOkAttribute
            )
        case .some(false):
            mainWindow.write(
                pad("No Meeting In Progress", maxWidth: width),
                attribute: statusBadAttribute
            )
        case .none:
            mainWindow.write(
                pad("No Meeting In Progress", maxWidth: width),
                attribute: .dim
            )
        }
    }
    
    private func writeChatOpenStatus(ok: Bool?, width: Int) {
        mainWindow.cursor.position = Point(x: (width + 1) * 2, y: 0)
        switch ok {
        case .some(true):
            mainWindow.write(
                pad("Chat Is Open", maxWidth: width), attribute: statusOkAttribute
            )
        case .some(false):
            mainWindow.write(
                pad("Chat Not Open", maxWidth: width), attribute: statusBadAttribute
            )
        case .none:
            mainWindow.write(
                pad("Chat Not Open", maxWidth: width), attribute: .dim
            )
        }
    }
    
    private func writeStatuses(_ status: ZoomApplicationStatus, terminalSize: Size) {
        let statusWidth: Int = (terminalSize.width - 2) / 3
        switch status {
        case .running(let meetingStatus):
            writeZoomRunningStatus(ok: true, width: statusWidth)
            switch meetingStatus {
            case .inProgress(let chatOpen):
                writeMeetingOngoingStatus(ok: true, width: statusWidth)
                writeChatOpenStatus(ok: chatOpen, width: statusWidth)
                
            case .notInProgress:
                writeMeetingOngoingStatus(ok: false, width: statusWidth)
                writeChatOpenStatus(ok: nil, width: statusWidth)
            }
            
        case .notRunning:
            writeZoomRunningStatus(ok: false, width: statusWidth)
            writeMeetingOngoingStatus(ok: nil, width: statusWidth)
            writeChatOpenStatus(ok: nil, width: statusWidth)
        }
    }
    
    private func writeProcessStatistics(_ model: Model, terminalSize: Size) {
        let uptimeText: String = intervalFormatter.string(
            from: model.startTime, to: Date()
        ) ?? "Since Process Start"
        let publishSuccessCount = model.publishSuccessCount
        let publishTotalCount = model.publishSuccessCount + model.publishFailureCount
        
        mainWindow.cursor.position = Point(x: 0, y: terminalSize.height - 1)
        mainWindow.write(
            "Up \(uptimeText) | Messages Published: \(publishSuccessCount)/\(publishTotalCount)"
                .padding(toLength: terminalSize.width, withPad: " ", startingAt: 0),
            attribute: metadataAttribute
        )
    }
    
    private func render(_ model: Model, terminalSize: Size) {
        writeStatuses(model.status, terminalSize: terminalSize)
        
        consoleWindow.size = Size(
            width: mainWindow.size.width, height: mainWindow.size.height - 1
        )
        consoleWindow.clear()
        for publishAttempt: PublishAttempt in model.publishAttempts {
            let errorLength: Int
            consoleWindow.write("[")
            switch publishAttempt.httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                let statusAttribute: Attribute = statusCode == 204 ? successAttribute : failureAttribute
                consoleWindow.write("\(statusCode)", attribute: statusAttribute)
                errorLength = 3
                
            case .failure(let error):
                consoleWindow.write("\(error.localizedDescription)", attribute: failureAttribute)
                errorLength = error.localizedDescription.count
            }
            let maxTextLength: Int = terminalSize.width - errorLength - 4 // 4 = [, ], space, and a space at the end
            let logOutputUntruncated: String = publishAttempt.chatMessage.description
                .replacingOccurrences(of: "\n", with: "⏎")
            let logOutput: String
            if logOutputUntruncated.count <= maxTextLength {
                logOutput = logOutputUntruncated
            } else {
                logOutput = logOutputUntruncated.prefix(maxTextLength - 1) + "…"
            }
            consoleWindow.write("] \(logOutput)\n")
        }
        consoleWindow.refresh()
        
        writeProcessStatistics(model, terminalSize: terminalSize)
        mainWindow.refresh()
    }
    
    func render(_ events: Observable<Result<PublishEvent, PublishError>>) -> Disposable {
        events
            .scan(Model()) { (model: Model, nextEvent: Result<PublishEvent, PublishError>) in
                var nextModel: Model = model
                
                switch nextEvent {
                case .success(.publish(let publishAttempt)):
                    nextModel.status = .running(meeting: .inProgress(chatOpen: true))
                    nextModel.publishAttempts = model.publishAttempts.suffix(1023) + [ publishAttempt ]
                    switch publishAttempt.httpResponseResult {
                    case .success(let response) where response.statusCode == 204:
                        nextModel.publishSuccessCount += 1
                    default:
                        nextModel.publishFailureCount += 1
                    }
                    
                case .success(.noOp):
                    nextModel.status = .running(meeting: .inProgress(chatOpen: true))
                    
                case .failure(let error):
                    switch error {
                    case .zoomNotRunning:
                        nextModel.status = .notRunning
                        nextModel.publishAttempts = []
                    case .noMeetingInProgress:
                        nextModel.status = .running(meeting: .notInProgress)
                        nextModel.publishAttempts = []
                    case .chatNotOpen:
                        nextModel.status = .running(meeting: .inProgress(chatOpen: false))
                        nextModel.publishAttempts = model.publishAttempts
                    }
                }
                
                return nextModel
            }
            .flatMapLatest { (model: Model) in
                terminalSizes
                    .do(onNext: { _ in
                        mainWindow.cursor.position = Point(x: 0, y: 0)
                        mainWindow.clearToEndOfLine()
                    })
                    .map { (model, $0) }
            }
            .subscribe(onNext: { (modelAndSize: (Model, Size)) in
                let (model, terminalSize): (Model, Size) = modelAndSize
                render(model, terminalSize: terminalSize)
            })
    }
}
