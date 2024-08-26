import Cocoa
import RxCocoa
import RxSwift
import ZoomChatPublisher

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    let publishEvents: Observable<Result<PublishEvent, PublishError>> = UserDefaults
        .standard.rx
        .observe(String.self, subscriberURLKey)
        .compactMap { $0 }
        .distinctUntilChanged()
        .flatMapLatest { urlSpec in
            ZoomChatPublisher(
                destinationURL: URLComponents(string: urlSpec)!
            ).scrapeAndPublishChatMessages()
        }
        .share()
    let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var settingsWindowController: NSWindowController = {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(
            withIdentifier: "settingsWindowController"
        ) as! NSWindowController
        if #available(macOS 13, *) {
            controller.window?.title = "Settings"
        }
        
        return controller
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if UserDefaults.standard.string(forKey: subscriberURLKey) == nil {
            UserDefaults.standard.setValue(
                defaultSubscriberURL, forKey: subscriberURLKey
            )
            settingsWindowController.showWindow(self)
        }
        
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue():true] as CFDictionary
        )
        
        let dockTileView: DockTileView = DockTileView(NSApplication.shared.dockTile)
        
        publishEvents
            .concatMap {
                return switch $0 {
                case .success(.noOp):
                    Observable.just(
                        DockTileView.Model(
                            leftIndicator: true,
                            centerIndicator: true,
                            rightIndicator: true,
                            broadcastState: .On
                        )
                    )
                    
                case .success(.publish(_)):
                    Observable
                        .zip(
                            Observable.from(
                                [
                                    DockTileView.Model(
                                        leftIndicator: true,
                                        centerIndicator: true,
                                        rightIndicator: true,
                                        broadcastState: .Broadcasting1
                                    ),
                                    DockTileView.Model(
                                        leftIndicator: true,
                                        centerIndicator: true,
                                        rightIndicator: true,
                                        broadcastState: .Broadcasting2
                                    ),
                                    DockTileView.Model(
                                        leftIndicator: true,
                                        centerIndicator: true,
                                        rightIndicator: true,
                                        broadcastState: .Broadcasting3
                                    ),
                                    DockTileView.Model(
                                        leftIndicator: true,
                                        centerIndicator: true,
                                        rightIndicator: true,
                                        broadcastState: .On
                                    )
                                ]
                            ),
                            Observable<Int>.interval(
                                .milliseconds(200), scheduler: MainScheduler.instance
                            )
                        )
                        .map { $0.0 }
                        .take(4)
                    
                case .failure(let error):
                    switch error {
                    case .zoomNotRunning:
                        Observable.just(
                            DockTileView.Model(
                                leftIndicator: false,
                                centerIndicator: nil,
                                rightIndicator: nil,
                                broadcastState: .Off
                            )
                        )
                        
                    case .noMeetingInProgress:
                        Observable.just(
                            DockTileView.Model(
                                leftIndicator: true,
                                centerIndicator: false,
                                rightIndicator: nil,
                                broadcastState: .Off
                            )
                        )
                        
                    case .chatNotOpen:
                        Observable.just(
                            DockTileView.Model(
                                leftIndicator: true,
                                centerIndicator: true,
                                rightIndicator: false,
                                broadcastState: .Off
                            )
                        )
                    }
                }
            }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .bind(to: dockTileView.rx.value)
            .disposed(by: disposeBag)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @IBAction private func showSettingsWindow(_ sender: NSMenuItem) {
        settingsWindowController.showWindow(sender)
    }
}

