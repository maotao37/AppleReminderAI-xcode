//
//  PermissionManager.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  权限管理器
//  统一管理提醒事项和日历的访问权限
//

import Foundation
import EventKit
import Combine

/// 权限管理器
/// 负责检查和请求提醒事项、日历的访问权限
@MainActor
class PermissionManager: ObservableObject {
    
    // MARK: - 单例
    
    static let shared = PermissionManager()
    
    // MARK: - 发布属性
    
    /// 提醒事项访问状态
    @Published var reminderStatus: EKAuthorizationStatus = .notDetermined
    
    /// 日历访问状态
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    
    /// 是否正在请求权限
    @Published var isRequestingPermission = false
    
    // MARK: - 私有属性
    
    /// EventKit 事件存储
    let eventStore = EKEventStore()
    
    // MARK: - 初始化
    
    private init() {
        checkCurrentStatus()
    }
    
    // MARK: - 状态检查
    
    /// 检查当前权限状态
    func checkCurrentStatus() {
        reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    /// 是否已获得提醒事项权限
    var hasReminderAccess: Bool {
        if #available(macOS 14.0, *) {
            return reminderStatus == .fullAccess
        } else {
            return reminderStatus == .authorized
        }
    }
    
    /// 是否已获得日历权限
    var hasCalendarAccess: Bool {
        if #available(macOS 14.0, *) {
            return calendarStatus == .fullAccess
        } else {
            return calendarStatus == .authorized
        }
    }
    
    /// 是否已获得所有必要权限
    var hasAllRequiredPermissions: Bool {
        hasReminderAccess && hasCalendarAccess
    }
    
    // MARK: - 权限请求
    
    /// 请求提醒事项访问权限
    func requestReminderAccess() async throws -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        do {
            // macOS 14+ 使用新的 API
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                checkCurrentStatus()
                return granted
            } else {
                // 旧版 API
                let granted = try await eventStore.requestAccess(to: .reminder)
                checkCurrentStatus()
                return granted
            }
        } catch {
            checkCurrentStatus()
            throw error
        }
    }
    
    /// 请求日历访问权限
    func requestCalendarAccess() async throws -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        do {
            // macOS 14+ 使用新的 API
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                checkCurrentStatus()
                return granted
            } else {
                // 旧版 API
                let granted = try await eventStore.requestAccess(to: .event)
                checkCurrentStatus()
                return granted
            }
        } catch {
            checkCurrentStatus()
            throw error
        }
    }
    
    /// 请求所有权限
    func requestAllPermissions() async throws {
        // 先请求提醒事项权限
        if !hasReminderAccess {
            _ = try await requestReminderAccess()
        }
        
        // 再请求日历权限
        if !hasCalendarAccess {
            _ = try await requestCalendarAccess()
        }
    }
    
    // MARK: - 状态描述
    
    /// 获取权限状态的描述文本
    func statusDescription(for status: EKAuthorizationStatus) -> String {
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return "完全访问" }
            if status == .writeOnly { return "仅写入" }
        }
        
        switch status {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已授权"
        default:
            return "未知"
        }
    }
    
    /// 获取权限状态的图标
    func statusIcon(for status: EKAuthorizationStatus) -> String {
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return "checkmark.circle.fill" }
            if status == .writeOnly { return "pencil.circle.fill" }
        }
        
        switch status {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    /// 获取权限状态的颜色名称
    func statusColorName(for status: EKAuthorizationStatus) -> String {
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return "green" }
            if status == .writeOnly { return "orange" }
        }
        
        switch status {
        case .authorized:
            return "green"
        case .denied, .restricted:
            return "red"
        case .notDetermined:
            return "gray"
        default:
            return "gray"
        }
    }
}
