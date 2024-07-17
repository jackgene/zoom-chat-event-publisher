//
//  AppDelegate.swift
//  App
//
//  Created by Jack Leow on 7/14/24.
//

import Cocoa
import RxSwift

@main
class AppDelegate: NSObject, NSApplicationDelegate {
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
        if UserDefaults.standard.string(forKey: receiverURLKey) == nil {
            UserDefaults.standard.setValue(
                defaultReceiverURL, forKey: receiverURLKey
            )
            settingsWindowController.showWindow(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @IBAction private func showSettingsWindow(_ sender: NSMenuItem) {
        settingsWindowController.showWindow(sender)
    }
}

