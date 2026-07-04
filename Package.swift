// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkspacePeek",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WorkspacePeek",
            path: "Sources/WorkspacePeek"
        )
    ]
)
