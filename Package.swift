// swift-tools-version: 6.2
// 仅供本地 `swift test` 运行纯逻辑单元测试（解析器、归一化、分组、重复规则）。
// 应用本体仍由 AppleReminderAI-xcode.xcodeproj 构建，二者互不影响。
import PackageDescription

let package = Package(
    name: "AppleReminderAI",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AppleReminderAICore",
            path: "AppleReminderAI-xcode",
            exclude: [
                "Info.plist",
                "AppleReminderAI.entitlements",
                "Assets.xcassets",
                // App 入口含 @main，不能进入库目标；其余源码不引用它
                "AppleReminderAIApp.swift",
                // CLT SDK 缺少 SwiftUI 宏插件（SwiftUIMacros），视图层只能在 Xcode/CI 中编译
                "Views",
            ],
            // 与 Xcode 工程的 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor 保持一致
            swiftSettings: [.swiftLanguageMode(.v5), .defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "AppleReminderAITests",
            dependencies: ["AppleReminderAICore"],
            path: "Tests/AppleReminderAITests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self),
                // CLT 环境下 swift-testing 宏插件不在默认搜索路径，需显式加载（仅影响本地测试）
                .unsafeFlags([
                    "-load-plugin-library",
                    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
                ]),
            ]
        ),
    ]
)
