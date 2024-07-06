import ArgumentParser
import Curses
import Foundation
import Logging
import LoggingFormatAndPipe
import RxSwift
import ZoomChatPublisher

@main
struct Main: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoom-chat-publisher",
        abstract: "Scrapes Zoom chat messages and publishes them to an HTTP endpoint."
    )
    
    @Option(name: .shortAndLong, help: "The URL to publish chat messages to.")
    var destinationURL: URLComponents
    
    func run() {
        URLSession.rx.shouldLogRequest = { _ in false }
        let disposeBag: DisposeBag = DisposeBag()
        let publisher: ZoomChatPublisher = ZoomChatPublisher(
            destinationURL: destinationURL
        )
        let terminalSizes: ReplaySubject<Size> = ReplaySubject.create(bufferSize: 1)
        
        // View
        class Handler<TerminalSizes: ObserverType>: CursesHandlerProtocol where TerminalSizes.Element == Size {
            let screen: Screen
            let terminalSizes: TerminalSizes

            init(_ screen: Screen, _ terminalSizes: TerminalSizes) {
                self.screen = screen
                self.terminalSizes = terminalSizes
            }
            
            func interruptHandler() {
                screen.shutDown()
                Main.exit(withError: nil)
            }
            
            func windowChangedHandler(_ terminalSize: Size) {
                terminalSizes.onNext(terminalSize)
            }
        }
        
        let screen: Screen = Screen.shared
        screen.startUp(handler: Handler(screen, terminalSizes))
        terminalSizes.onNext(screen.window.size)
        
        let statusOkAttribute: Attribute
        let statusBadAttribute: Attribute
        let successAttribute: Attribute
        let failureAttribute: Attribute
        let metadataAttribute: Attribute
        let colors: Colors = Colors.shared
        if colors.areSupported {
            colors.startUp()
            statusOkAttribute = colors.newPair(foreground: .white, background: .green)
            statusBadAttribute = colors.newPair(foreground: .white, background: .red)
            successAttribute = colors.newPair(foreground: .green, background: .black)
            failureAttribute = colors.newPair(foreground: .red, background: .black)
            metadataAttribute = colors.newPair(foreground: .black, background: .white)
        } else {
            statusOkAttribute = Attribute.reverse
            statusBadAttribute = Attribute.blink
            successAttribute = Attribute.dim
            failureAttribute = Attribute.blink
            metadataAttribute = Attribute.reverse
        }
        
        let view: View = CursesView(
            screen: screen,
            statusOkAttribute: statusOkAttribute, statusBadAttribute: statusBadAttribute,
            successAttribute: successAttribute, failureAttribute: failureAttribute,
            metadataAttribute: metadataAttribute, terminalSizes: terminalSizes
        )
        view.render(publisher.scrapeAndPublishChatMessages())
            .disposed(by: disposeBag)
        
        screen.wait()
    }
}
