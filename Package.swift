// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fuel",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Fuel",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Fuel"
        )
    ]
)
