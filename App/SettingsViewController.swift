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
    @IBOutlet private var subscriberURLField: NSTextField!
    @IBOutlet private var subscriberURLError: NSView!
    private lazy var disposeBag: DisposeBag = {
        let appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.disposeBag
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if
            let url: String = UserDefaults.standard.string(
                forKey: subscriberURLKey
            )
        {
            subscriberURLField.stringValue = url
        }
        
        let subscriberURLs: Observable<String?> = subscriberURLField.rx
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
        subscriberURLs
            .map { $0 != nil }
            .bind(to: subscriberURLError.rx.isHidden)
            .disposed(by: disposeBag)
        subscriberURLs
            .debounce(.milliseconds(200), scheduler: MainScheduler.instance)
            .compactMap { $0 }
            .distinctUntilChanged()
            .bind {
                UserDefaults.standard.setValue($0, forKey: subscriberURLKey)
            }
            .disposed(by: disposeBag)
    }
}

