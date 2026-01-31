// swift-tools-version: 5.9
// Package.swift for Suibhne CLI

import PackageDescription

let package = Package(
    name: "suibhne-cli",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "suibhne", targets: ["suibhne-cli"])
    ],
    targets: [
        .executableTarget(
            name: "suibhne-cli",
            dependencies: [],
            path: "CLI"
        )
    ]
)
