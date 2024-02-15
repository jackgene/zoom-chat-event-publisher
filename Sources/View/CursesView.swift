import Curses
import Foundation
import RxSwift

struct CursesView<TerminalSizes: Observable<Size>>: View {
    private let screen: Screen
    private let mainWindow: Window
    private let consoleWindow: Window
    private let statusOkAttribute: Attribute
    private let statusBadAttribute: Attribute
    private let successAttribute: Attribute
    private let failureAttribute: Attribute
    private let terminalSizes: TerminalSizes
    
    init(
        screen: Screen,
        statusOkAttribute: Attribute, statusBadAttribute: Attribute,
        successAttribute: Attribute, failureAttribute: Attribute,
        terminalSizes: TerminalSizes
    ) {
        self.screen = screen
        self.mainWindow = screen.window
        self.consoleWindow = screen.newWindow(
            position: Point(x: 0, y: 1),
            size: Size(width: mainWindow.size.width, height: mainWindow.size.height - 1)
        )
        self.consoleWindow.setScroll(enabled: true)
        self.statusOkAttribute = statusOkAttribute
        self.statusBadAttribute = statusBadAttribute
        self.successAttribute = successAttribute
        self.failureAttribute = failureAttribute
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
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write(pad("Zoom Is Running", maxWidth: width))
            mainWindow.turnOff(statusOkAttribute)
        } else {
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write(pad("Zoom Not Running", maxWidth: width))
            mainWindow.turnOff(statusBadAttribute)
        }
    }
    
    private func writeMeetingOngoingStatus(ok: Bool?, width: Int) {
        mainWindow.cursor.position = Point(x: width + 1, y: 0)
        switch ok {
        case .some(true):
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write(pad("Meeting In Progress", maxWidth: width))
            mainWindow.turnOff(statusOkAttribute)
        case .some(false):
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write(pad("No Meeting In Progress", maxWidth: width))
            mainWindow.turnOff(statusBadAttribute)
        case .none:
            mainWindow.turnOn(.dim)
            mainWindow.write(pad("No Meeting In Progress", maxWidth: width))
            mainWindow.turnOff(.dim)
        }
    }
    
    private func writeChatOpenStatus(ok: Bool?, width: Int) {
        mainWindow.cursor.position = Point(x: (width + 1) * 2, y: 0)
        switch ok {
        case .some(true):
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write(pad("Chat Is Open", maxWidth: width))
            mainWindow.turnOff(statusOkAttribute)
        case .some(false):
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write(pad("Chat Not Open", maxWidth: width))
            mainWindow.turnOff(statusBadAttribute)
        case .none:
            mainWindow.turnOn(.dim)
            mainWindow.write(pad("Chat Not Open", maxWidth: width))
            mainWindow.turnOff(.dim)
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
    
    private func render(_ model: Model, terminalSize: Size) {
        writeStatuses(model.status, terminalSize: terminalSize)
        
        consoleWindow.clear()
        for publishAttempt: PublishAttempt in model.publishAttempts {
            let errorLength: Int
            consoleWindow.write("[")
            switch publishAttempt.httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                let statusAttribute: Attribute = statusCode == 204 ? successAttribute : failureAttribute
                consoleWindow.turnOn(statusAttribute)
                consoleWindow.write("\(statusCode)")
                consoleWindow.turnOff(statusAttribute)
                errorLength = 3
                
            case .failure(let error):
                consoleWindow.turnOn(failureAttribute)
                consoleWindow.write("\(error.localizedDescription)")
                consoleWindow.turnOff(failureAttribute)
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
        mainWindow.refresh()
    }
    
    func render(_ events: Observable<Result<PublishEvent, PublishError>>) -> Disposable {
        events
            .scan(Model()) { (model: Model, nextEvent: Result<PublishEvent, PublishError>) in
                switch nextEvent {
                case .success(.publish(let publishAttempt)):
                    return Model(
                        status: .running(meeting: .inProgress(chatOpen: true)),
                        publishAttempts: model.publishAttempts.suffix(1023) + [ publishAttempt ]
                    )
                    
                case .success(.noOp):
                    return Model(
                        status: .running(meeting: .inProgress(chatOpen: true)),
                        publishAttempts: model.publishAttempts
                    )
                    
                case .failure(let error):
                    let status: ZoomApplicationStatus
                    let publishAttempts: [PublishAttempt]
                    switch error {
                    case .zoomNotRunning:
                        status = .notRunning
                        publishAttempts = []
                    case .noMeetingInProgress:
                        status = .running(meeting: .notInProgress)
                        publishAttempts = []
                    case .chatNotOpen:
                        status = .running(meeting: .inProgress(chatOpen: false))
                        publishAttempts = model.publishAttempts
                    }
                    
                    return Model(
                        status: status,
                        publishAttempts: publishAttempts
                    )
                }
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
