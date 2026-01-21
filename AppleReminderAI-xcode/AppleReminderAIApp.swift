//
//  AppleReminderAIApp.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  应用入口点
//

import SwiftUI
import Combine

@main
struct AppleReminderAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    /// 使用 @State 存储菜单栏显示状态，避免 @ObservedObject 导致的循环更新
    @State private var isMenuBarVisible: Bool = AppSettings.shared.isMenuBarVisible
    
    var body: some Scene {
        // 主窗口
        WindowGroup(id: "main") {
            MainView()
                .frame(minWidth: 500, minHeight: 600)
                // 在主视图中监听设置变化，同步到 App 的 @State
                .onReceive(AppSettings.shared.$isMenuBarVisible) { newValue in
                    // 延迟更新以避免在视图更新期间修改状态
                    DispatchQueue.main.async {
                        isMenuBarVisible = newValue
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // 状态栏图标（根据设置控制是否显示）
        MenuBarExtra("苹果提醒事项 AI", systemImage: "sparkles", isInserted: $isMenuBarVisible) {
            Button("显示主界面") {
                openMainWindow()
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            Button("设置...") {
                openSettingsWindow()
            }
            
            Divider()
            
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
    
    /// 打开主窗口
    private func openMainWindow() {
        // 设置激活策略为普通模式（显示在 Dock 中）
        NSApp.setActivationPolicy(.regular)
        
        // 使用 NSRunningApplication 强制激活当前应用
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        // 延迟执行窗口操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 尝试找到已有窗口
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                // 使用 orderFrontRegardless 强制将窗口置于最前
                window.orderFrontRegardless()
                window.makeKey()
            } else {
                // 如果没有已有窗口，通过 openWindow 创建新窗口
                self.openWindow(id: "main")
            }
            
            // 再次强制激活
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
        }
    }
    
    /// 打开设置界面
    private func openSettingsWindow() {
        openMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
        }
    }
}

/// 应用代理类，处理底层 macOS 生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 允许窗口关闭时不退出应用
        // 通过监听窗口关闭事件来决定是否隐藏 Dock
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        
        // 检查是否所有窗口已关闭，如果是且启用了状态栏，则隐藏 Dock
        checkDockVisibility()
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        // 延迟执行以等待窗口正式关闭
        DispatchQueue.main.async {
            self.checkDockVisibility()
        }
    }
    
    /// 根据当前窗口状态和设置决定是否显示 Dock 图标
    func checkDockVisibility() {
        // 延迟执行以避免在视图更新期间修改状态
        DispatchQueue.main.async {
            let hasVisibleWindows = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
            
            if !hasVisibleWindows && AppSettings.shared.isMenuBarVisible {
                // 如果没有可见窗口且启用了状态栏，将应用转为“附属”模式（隐藏 Dock）
                NSApp.setActivationPolicy(.accessory)
            } else {
                // 反之，维持普通模式
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    
    /// 当最后一个窗口关闭时，不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
