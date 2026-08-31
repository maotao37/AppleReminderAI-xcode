//
//  CalendarService.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  日历服务
//  封装 EventKit 日历事件相关操作
//

import Foundation
import EventKit

/// 日历服务错误
enum CalendarServiceError: Error, LocalizedError {
    case noAccess
    case saveFailed(String)
    case calendarNotFound
    case eventNotFound
    case missingDate
    case duplicate
    
    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "没有日历访问权限"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        case .calendarNotFound:
            return "找不到指定的日历"
        case .eventNotFound:
            return "找不到指定的事件"
        case .missingDate:
            return "日历事件必须设置开始日期"
        case .duplicate:
            return "目标日历中已存在标题和时间相同的事件"
        }
    }
}

/// 日历服务
/// 负责创建、管理日历事件
class CalendarService {
    
    // MARK: - 单例
    
    static let shared = CalendarService()
    
    // MARK: - 私有属性
    
    private let permissionManager = PermissionManager.shared
    private var eventStore: EKEventStore { permissionManager.eventStore }
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 日历管理
    
    /// 获取所有日历
    func fetchCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event).filter(\.allowsContentModifications)
    }
    
    /// 获取默认日历
    func defaultCalendar() -> EKCalendar? {
        // 首先检查用户设置的默认日历
        if let calendarID = AppSettings.shared.defaultCalendarID,
           let calendar = eventStore.calendar(withIdentifier: calendarID),
           calendar.allowsContentModifications {
            return calendar
        }
        
        // 否则使用系统默认日历
        guard let calendar = eventStore.defaultCalendarForNewEvents,
              calendar.allowsContentModifications else {
            return fetchCalendars().first
        }
        return calendar
    }
    
    /// 根据 ID 获取日历
    func getCalendar(by identifier: String) -> EKCalendar? {
        return eventStore.calendar(withIdentifier: identifier)
    }
    
    // MARK: - 事件创建
    
    /// 从解析的事项创建日历事件
    /// - Parameters:
    ///   - item: 解析后的事项
    ///   - calendar: 目标日历（可选，默认使用默认日历）
    /// - Returns: 创建的事件
    @discardableResult
    func createEvent(from item: ParsedItem, in calendar: EKCalendar? = nil) async throws -> EKEvent {
        guard permissionManager.hasCalendarAccess else {
            throw CalendarServiceError.noAccess
        }

        let item = ScheduleNormalizer.normalize(item)
        guard let startDate = item.dueDate else {
            throw CalendarServiceError.missingDate
        }

        let targetCalendar = calendar ?? defaultCalendar()
        guard let eventCalendar = targetCalendar else {
            throw CalendarServiceError.calendarNotFound
        }

        if hasDuplicate(item, in: eventCalendar) {
            throw CalendarServiceError.duplicate
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventCalendar
        event.title = item.title
        event.notes = item.notes
        event.isAllDay = item.isAllDay

        event.startDate = startDate
        if item.isAllDay {
            // EventKit uses an exclusive end date for all-day events.
            let inclusiveEnd = item.endDate ?? startDate
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: inclusiveEnd)
        } else {
            event.endDate = item.endDate ?? startDate.addingTimeInterval(3600)
        }

        if ScheduleNormalizer.isAlertEnabled(for: item) {
            let offset = item.alertOffsetMinutes ?? ScheduleNormalizer.defaultAlertOffset(for: item)
            let alarm = EKAlarm(relativeOffset: TimeInterval(offset * 60))
            event.addAlarm(alarm)
        }

        if let recurrenceRule = EventKitRecurrenceBuilder.makeRule(for: item) {
            event.recurrenceRules = [recurrenceRule]
        }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event
        } catch {
            throw CalendarServiceError.saveFailed(error.localizedDescription)
        }
    }

    func removeEvent(identifier: String) throws {
        guard permissionManager.hasCalendarAccess else { throw CalendarServiceError.noAccess }
        guard let event = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent else {
            throw CalendarServiceError.eventNotFound
        }
        do {
            let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
            try eventStore.remove(event, span: span, commit: true)
        } catch {
            throw CalendarServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func hasDuplicate(_ item: ParsedItem, in calendar: EKCalendar) -> Bool {
        guard let start = item.dueDate else { return false }
        let rangeStart = start.addingTimeInterval(-60)
        let rangeEnd = item.isAllDay
            ? (Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400))
            : start.addingTimeInterval(60)

        return fetchEvents(from: rangeStart, to: rangeEnd, in: [calendar]).contains { event in
            let sameTitle = event.title.compare(item.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            if item.isAllDay {
                return sameTitle && event.isAllDay && Calendar.current.isDate(event.startDate, inSameDayAs: start)
            }
            return sameTitle && abs(event.startDate.timeIntervalSince(start)) < 60
        }
    }
    
    // MARK: - 事件查询
    
    /// 获取指定日期范围内的事件
    func fetchEvents(from startDate: Date, to endDate: Date, in calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    /// 获取今天的事件
    func fetchTodayEvents(in calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return fetchEvents(from: startOfDay, to: endOfDay, in: calendars)
    }
    
    /// 获取本周的事件
    func fetchThisWeekEvents(in calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }
        
        return fetchEvents(from: weekStart, to: weekEnd, in: calendars)
    }
}
