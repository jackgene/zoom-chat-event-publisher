// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zoom-chat-publisher",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/adorkable/swift-log-format-and-pipe.git", exact: "0.1.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.4.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.1"),
        .package(url: "https://github.com/jackgene/Curses.git", exact: "1.0.4"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.7.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ZoomChatPublisher",
            dependencies: [
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
            ],
            path: "ZoomChatPublisher"
        ),
        .executableTarget(
            name: "zoom-chat-publisher",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Curses", package: "Curses"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "LoggingFormatAndPipe", package: "swift-log-format-and-pipe"),
                .target(name: "ZoomChatPublisher"),
            ],
            path: "CLI"
        ),
    ]
)
