//
//  ViewController.swift
//  App
//
//  Created by Jack Leow on 7/14/24.
//

import Cocoa
import RxCocoa
import RxSwift

class SettingsViewController: NSViewController {
    @IBOutlet private var receiverURLField: NSTextField!
    @IBOutlet private var receiverURLError: NSView!
    private lazy var disposeBag: DisposeBag = {
        let appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.disposeBag
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if
            let url: String = UserDefaults.standard.string(
                forKey: receiverURLKey
            )
        {
            receiverURLField.stringValue = url
        }
        
        let receiverURLs: Observable<String?> = receiverURLField.rx
            .text.orEmpty
            .map {
                URL(string: $0)
                    .flatMap { url in
                        url.scheme.flatMap {
                            switch $0 {
                            case "http": url.absoluteString
                            case "https": url.absoluteString
                            default: nil
                            }
                        }
                    }
            }
            .share()
        receiverURLs
            .map { $0 != nil }
            .bind(to: receiverURLError.rx.isHidden)
            .disposed(by: disposeBag)
        receiverURLs
            .debounce(.milliseconds(200), scheduler: MainScheduler.instance)
            .compactMap { $0 }
            .distinctUntilChanged()
            .bind {
                UserDefaults.standard.setValue($0, forKey: receiverURLKey)
            }
            .disposed(by: disposeBag)
    }
}

