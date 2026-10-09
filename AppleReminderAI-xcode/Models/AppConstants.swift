//
//  AppConstants.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  跨模块共享的常量定义
//

import Foundation

/// 跨模块共用的通知名，避免魔法字符串
extension Notification.Name {
    /// 从菜单栏请求打开设置界面
    static let openSettingsRequest = Notification.Name("AppleReminderAIOpenSettings")
}
