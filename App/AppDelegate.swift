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
            .map {
                switch $0 {
                case .success(_):
                    DockTileView.Model(
                        leftIndicator: true,
                        centerIndicator: true,
                        rightIndicator: true
                    )
                    
                case .failure(let error):
                    switch error {
                    case .zoomNotRunning:
                        DockTileView.Model(
                            leftIndicator: false,
                            centerIndicator: nil,
                            rightIndicator: nil
                        )
                    case .noMeetingInProgress:
                        DockTileView.Model(
                            leftIndicator: true,
                            centerIndicator: false,
                            rightIndicator: nil
                        )
                    case .chatNotOpen:
                        DockTileView.Model(
                            leftIndicator: true,
                            centerIndicator: true,
                            rightIndicator: false
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

