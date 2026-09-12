// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LifePlanPro",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LifePlanPro", targets: ["LifePlanPro"])],
    targets: [.executableTarget(name: "LifePlanPro", path: "Sources/LifePlanPro")]
)
