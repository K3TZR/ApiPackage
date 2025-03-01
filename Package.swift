// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApiPackage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    
    products: [
      .library(name: "ApiPackage", targets: ["ApiPackage"]),
    ],
    
    dependencies: [
      .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.5"),
      .package(url: "https://github.com/auth0/JWTDecode.swift", from: "2.6.0"),
    ],
    
    // --------------- Modules ---------------
    targets: [
      // ApiPackage
      .target( name: "ApiPackage", dependencies: [
        .product(name: "JWTDecode", package: "JWTDecode.swift"),
        .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
      ]),
    ]
)
