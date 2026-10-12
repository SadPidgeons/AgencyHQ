// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgencyHQ",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.99.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgencyHQ",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
    ]
)
