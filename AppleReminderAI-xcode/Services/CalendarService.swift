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
        return eventStore.calendars(for: .event)
    }
    
    /// 获取默认日历
    func defaultCalendar() -> EKCalendar? {
        // 首先检查用户设置的默认日历
        if let calendarID = AppSettings.shared.defaultCalendarID,
           let calendar = eventStore.calendar(withIdentifier: calendarID) {
            return calendar
        }
        
        // 否则使用系统默认日历
        return eventStore.defaultCalendarForNewEvents
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
        // 检查权限
        guard permissionManager.hasCalendarAccess else {
            throw CalendarServiceError.noAccess
        }
        
        // 获取目标日历
        let targetCalendar = calendar ?? defaultCalendar()
        guard let eventCalendar = targetCalendar else {
            throw CalendarServiceError.calendarNotFound
        }
        
        // 创建事件
        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventCalendar
        event.title = item.title
        event.notes = item.notes
        event.isAllDay = item.isAllDay
        
        // 设置开始和结束时间
        if let startDate = item.dueDate {
            event.startDate = startDate
            
            if var endDate = item.endDate {
                // 确保结束时间不早于开始时间
                if endDate < startDate {
                    endDate = startDate.addingTimeInterval(3600)
                }
                event.endDate = endDate
            } else if item.isAllDay {
                // 全天事件，结束日期为开始日期
                event.endDate = startDate
            } else {
                // 默认持续 1 小时
                event.endDate = startDate.addingTimeInterval(3600)
            }
        } else {
            // 如果没有日期，使用当前时间
            let now = Date()
            event.startDate = now
            event.endDate = now.addingTimeInterval(3600)
        }
        
        // 设置提醒
        if !item.isAllDay {
            // 非全天事件，提前 15 分钟提醒
            let alarm = EKAlarm(relativeOffset: -15 * 60)
            event.addAlarm(alarm)
        }
        
        // 设置重复规则
        if item.recurrence != .none {
            event.recurrenceRules = [createRecurrenceRule(for: item.recurrence)]
        }
        
        // 保存事件
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event
        } catch {
            throw CalendarServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 重复规则
    
    /// 创建重复规则
    private func createRecurrenceRule(for recurrence: RecurrenceRule) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        let interval: Int
        
        switch recurrence {
        case .none:
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
