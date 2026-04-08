// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacSpeechToAIToText",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "MacSpeechToAIToText",
            dependencies: [
                "WhisperKit",
                "HotKey",
            ],
            path: "MacSpeechToAIToText",
            resources: [
                .process("Audio/Sounds")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "MacSpeechToAIToTextTests",
            dependencies: ["MacSpeechToAIToText"],
            path: "MacSpeechToAIToTextTests"
        ),
    ]
)
