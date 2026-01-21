//
//  ReminderService.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  提醒事项服务
//  封装 EventKit 提醒事项相关操作
//

import Foundation
import EventKit

/// 提醒事项服务错误
enum ReminderServiceError: Error, LocalizedError {
    case noAccess
    case saveFailed(String)
    case listNotFound
    case reminderNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "没有提醒事项访问权限"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        case .listNotFound:
            return "找不到指定的提醒事项列表"
        case .reminderNotFound:
            return "找不到指定的提醒事项"
        }
    }
}

/// 提醒事项服务
/// 负责创建、管理提醒事项
class ReminderService {
    
    // MARK: - 单例
    
    static let shared = ReminderService()
    
    // MARK: - 私有属性
    
    private let permissionManager = PermissionManager.shared
    private var eventStore: EKEventStore { permissionManager.eventStore }
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 列表管理
    
    /// 获取所有提醒事项列表
    func fetchReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder)
    }
    
    /// 获取默认提醒事项列表
    func defaultReminderList() -> EKCalendar? {
        // 首先检查用户设置的默认列表
        if let listID = AppSettings.shared.defaultReminderListID,
           let list = eventStore.calendar(withIdentifier: listID) {
            return list
        }
        
        // 否则使用系统默认列表
        return eventStore.defaultCalendarForNewReminders()
    }
    
    /// 根据 ID 获取列表
    func getReminderList(by identifier: String) -> EKCalendar? {
        return eventStore.calendar(withIdentifier: identifier)
    }
    
    // MARK: - 提醒事项创建
    
    /// 从解析的事项创建提醒事项
    /// - Parameters:
    ///   - item: 解析后的事项
    ///   - list: 目标列表（可选，默认使用默认列表）
    /// - Returns: 创建的提醒事项
    @discardableResult
    func createReminder(from item: ParsedItem, in list: EKCalendar? = nil) async throws -> EKReminder {
        // 检查权限
        guard permissionManager.hasReminderAccess else {
            throw ReminderServiceError.noAccess
        }
        
        // 获取目标列表
        let targetList = list ?? defaultReminderList()
        guard let reminderList = targetList else {
            throw ReminderServiceError.listNotFound
        }
        
        // 创建提醒事项
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = reminderList
        reminder.title = item.title
        reminder.notes = item.notes
        reminder.priority = item.priorityValue
        
        // 设置截止日期
        if let dueDate = item.dueDate {
            let calendar = Calendar.current
            if item.isAllDay {
                // 全天事项只设置日期部分
                reminder.dueDateComponents = calendar.dateComponents(
                    [.year, .month, .day],
                    from: dueDate
                )
            } else {
                // 包含时间
                reminder.dueDateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
                
                // 添加提醒闹钟
                let alarm = EKAlarm(absoluteDate: dueDate)
                reminder.addAlarm(alarm)
            }
        }
        
        // 设置重复规则
        if item.recurrence != .none {
            reminder.recurrenceRules = [createRecurrenceRule(for: item.recurrence)]
        }
        
        // 保存提醒事项
        do {
            try eventStore.save(reminder, commit: true)
            return reminder
        } catch {
            throw ReminderServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 重复规则
    
    /// 创建重复规则
    private func createRecurrenceRule(for recurrence: RecurrenceRule) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        let interval: Int
        
        switch recurrence {
        case .none:
            // 不应该到达这里
            frequency = .daily
            interval = 1
        case .daily:
            frequency = .daily
            interval = 1
        case .weekly:
            frequency = .weekly
            interval = 1
        case .biweekly:
            frequency = .weekly
            interval = 2
        case .monthly:
            frequency = .monthly
            interval = 1
        case .yearly:
            frequency = .yearly
            interval = 1
        }
        
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
    }
    
    // MARK: - 提醒事项查询
    
    /// 获取未完成的提醒事项
    func fetchIncompleteReminders(in lists: [EKCalendar]? = nil) async -> [EKReminder] {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: lists
        )
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    /// 获取指定日期范围内的提醒事项
    func fetchReminders(from startDate: Date, to endDate: Date, in lists: [EKCalendar]? = nil) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: lists)
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let filtered = (reminders ?? []).filter { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else { return false }
                    return dueDate >= startDate && dueDate <= endDate
                }
                continuation.resume(returning: filtered)
            }
        }
    }
}
