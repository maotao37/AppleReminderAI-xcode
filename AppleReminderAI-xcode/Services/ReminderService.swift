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
    case duplicate
    
    var errorDescription: String? {
        switch self {
        case .noAccess:
            return L10n.ReminderError.noAccess
        case .saveFailed(let message):
            return L10n.ReminderError.saveFailed(message)
        case .listNotFound:
            return L10n.ReminderError.listNotFound
        case .reminderNotFound:
            return L10n.ReminderError.notFound
        case .duplicate:
            return L10n.ReminderError.duplicate
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

    // MARK: - 查重缓存

    /// 列表内未完成提醒的查重索引（避免每次创建都全量拉取大列表）
    private struct DuplicateIndex {
        let fetchedAt: Date
        /// (归一化标题, 截止日期)
        let entries: [(title: String, dueDate: Date?)]
    }

    private var duplicateIndexCache: [String: DuplicateIndex] = [:]

    /// 查重缓存有效期；创建/删除成功后立即失效
    private let duplicateCacheTTL: TimeInterval = 5
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 列表管理
    
    /// 获取所有提醒事项列表
    func fetchReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder).filter(\.allowsContentModifications)
    }
    
    /// 获取默认提醒事项列表
    func defaultReminderList() -> EKCalendar? {
        // 首先检查用户设置的默认列表
        if let listID = AppSettings.shared.defaultReminderListID,
           let list = eventStore.calendar(withIdentifier: listID),
           list.allowsContentModifications {
            return list
        }
        
        // 否则使用系统默认列表
        guard let list = eventStore.defaultCalendarForNewReminders(),
              list.allowsContentModifications else {
            return fetchReminderLists().first
        }
        return list
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
        guard permissionManager.hasReminderAccess else {
            throw ReminderServiceError.noAccess
        }

        let item = ScheduleNormalizer.normalize(item)
        let targetList = list ?? defaultReminderList()
        guard let reminderList = targetList else {
            throw ReminderServiceError.listNotFound
        }

        if await hasDuplicate(item, in: reminderList) {
            throw ReminderServiceError.duplicate
        }

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
                reminder.dueDateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
            }

            if ScheduleNormalizer.isAlertEnabled(for: item) {
                let offset = item.alertOffsetMinutes ?? ScheduleNormalizer.defaultAlertOffset(for: item)
                let alertDate = dueDate.addingTimeInterval(TimeInterval(offset * 60))
                let alarm = EKAlarm(absoluteDate: alertDate)
                reminder.addAlarm(alarm)
            }
        }

        if let recurrenceRule = EventKitRecurrenceBuilder.makeRule(for: item) {
            reminder.recurrenceRules = [recurrenceRule]
        }
        
        // 保存提醒事项
        do {
            try eventStore.save(reminder, commit: true)
            invalidateDuplicateIndex(for: reminderList.calendarIdentifier)
            return reminder
        } catch {
            throw ReminderServiceError.saveFailed(error.localizedDescription)
        }
    }

    func removeReminder(identifier: String) throws {
        guard permissionManager.hasReminderAccess else { throw ReminderServiceError.noAccess }
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ReminderServiceError.reminderNotFound
        }
        do {
            try eventStore.remove(reminder, commit: true)
            invalidateDuplicateIndex(for: reminder.calendar?.calendarIdentifier)
        } catch {
            throw ReminderServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func hasDuplicate(_ item: ParsedItem, in list: EKCalendar) async -> Bool {
        let entries = await duplicateIndex(for: list).entries
        let normalizedTitle = item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return entries.contains { entry in
            guard entry.title == normalizedTitle else { return false }

            switch (item.dueDate, entry.dueDate) {
            case (nil, nil):
                return true
            case let (expected?, actual?):
                if item.isAllDay {
                    return Calendar.current.isDate(expected, inSameDayAs: actual)
                }
                return abs(expected.timeIntervalSince(actual)) < 60
            default:
                return false
            }
        }
    }

    /// 获取（或按 TTL 刷新）列表的查重索引
    private func duplicateIndex(for list: EKCalendar) async -> DuplicateIndex {
        let listID = list.calendarIdentifier
        if let cached = duplicateIndexCache[listID],
           Date().timeIntervalSince(cached.fetchedAt) < duplicateCacheTTL {
            return cached
        }

        let reminders = await fetchIncompleteReminders(in: [list])
        let index = DuplicateIndex(
            fetchedAt: Date(),
            entries: reminders.map { reminder in
                let title = (reminder.title ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return (title, reminder.dueDateComponents?.date)
            }
        )
        duplicateIndexCache[listID] = index
        return index
    }

    private func invalidateDuplicateIndex(for listID: String?) {
        guard let listID else { return }
        duplicateIndexCache.removeValue(forKey: listID)
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
