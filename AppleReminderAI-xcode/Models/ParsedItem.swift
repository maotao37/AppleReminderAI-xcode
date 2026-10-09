//
//  ParsedItem.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  解析后的事项数据模型
//

import Foundation

/// 事项类型枚举
enum ItemType: String, CaseIterable, Codable {
    case reminder = "提醒事项"
    case calendar = "日历事件"
    
    /// 获取对应的图标
    var icon: String {
        switch self {
        case .reminder:
            return "checkmark.circle"
        case .calendar:
            return "calendar"
        }
    }
}

/// 重复周期枚举
enum RecurrenceRule: String, CaseIterable, Codable {
    case none = "不重复"
    case daily = "每天"
    case weekdays = "工作日"
    case weekly = "每周"
    case biweekly = "每两周"
    case monthly = "每月"
    case yearly = "每年"
    
    /// 获取对应的图标
    var icon: String {
        switch self {
        case .none:
            return "arrow.counterclockwise.circle"
        case .daily:
            return "sun.max"
        case .weekdays:
            return "calendar.day.timeline.left"
        case .weekly:
            return "calendar.badge.clock"
        case .biweekly:
            return "calendar.badge.plus"
        case .monthly:
            return "calendar.circle"
        case .yearly:
            return "gift"
        }
    }
}

/// 优先级枚举
enum Priority: Int, CaseIterable {
    case none = 0      // 无优先级
    case low = 9       // 低优先级
    case medium = 5    // 中优先级
    case high = 1      // 高优先级
    
    var displayName: String {
        switch self {
        case .none:
            return L10n.PriorityDisplay.none
        case .low:
            return L10n.PriorityDisplay.low
        case .medium:
            return L10n.PriorityDisplay.medium
        case .high:
            return L10n.PriorityDisplay.high
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "minus"
        case .low:
            return "exclamationmark"
        case .medium:
            return "exclamationmark.2"
        case .high:
            return "exclamationmark.3"
        }
    }
}

/// 解析后的事项模型
/// 用于存储从自然语言解析出的提醒事项或日历事件信息
struct ParsedItem: Identifiable, Codable {
    let id: UUID
    var type: ItemType              // 事项类型
    var title: String               // 标题
    var notes: String?              // 备注
    var dueDate: Date?              // 截止/开始时间
    var endDate: Date?              // 结束时间（仅日历事件）
    var isAllDay: Bool              // 是否全天事件
    var priorityValue: Int          // 优先级值 (EventKit使用: 0=无, 1-4=高, 5=中, 6-9=低)
    var recurrence: RecurrenceRule  // 重复周期
    var recurrenceInterval: Int?    // 重复间隔，nil 表示 1
    var recurrenceWeekdays: [Int]?  // ISO 星期：1=周一，7=周日
    var recurrenceEndDate: Date?    // 重复截止日期
    var recurrenceCount: Int?       // 重复次数
    var recurrenceDaysOfMonth: [Int]?  // 月内日期（1-31），用于"每月15号"
    var recurrenceMonthsOfYear: [Int]? // 月份（1-12），用于"每年3月5日"
    var recurrenceSetPosition: Int?    // 月内第 N 个星期几：1-4=第 N 个，-1=最后一个
    var alertEnabled: Bool?         // nil 表示使用类型默认值
    var alertOffsetMinutes: Int?    // 相对事项时间的分钟数，提前为负数
    var targetGroupName: String?    // AI 或本地规则推荐的列表/日历名称
    var targetGroupIdentifier: String? // 最终匹配到的 EventKit 分组 ID
    var confidence: Double          // 解析置信度 (0.0 - 1.0)
    var originalText: String        // 原始输入文本
    
    /// 便捷初始化方法
    init(
        id: UUID = UUID(),
        type: ItemType = .reminder,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        priorityValue: Int = 0,
        recurrence: RecurrenceRule = .none,
        recurrenceInterval: Int? = nil,
        recurrenceWeekdays: [Int]? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceCount: Int? = nil,
        recurrenceDaysOfMonth: [Int]? = nil,
        recurrenceMonthsOfYear: [Int]? = nil,
        recurrenceSetPosition: Int? = nil,
        alertEnabled: Bool? = nil,
        alertOffsetMinutes: Int? = nil,
        targetGroupName: String? = nil,
        targetGroupIdentifier: String? = nil,
        confidence: Double = 1.0,
        originalText: String = ""
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.priorityValue = priorityValue
        self.recurrence = recurrence
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceCount = recurrenceCount
        self.recurrenceDaysOfMonth = recurrenceDaysOfMonth
        self.recurrenceMonthsOfYear = recurrenceMonthsOfYear
        self.recurrenceSetPosition = recurrenceSetPosition
        self.alertEnabled = alertEnabled
        self.alertOffsetMinutes = alertOffsetMinutes
        self.targetGroupName = targetGroupName
        self.targetGroupIdentifier = targetGroupIdentifier
        self.confidence = confidence
        self.originalText = originalText
    }
    
    /// 重复规则显示文本（附带月内日期、月份或"第 N 个星期X"细节）
    var recurrenceSummary: String {
        switch recurrence {
        case .monthly:
            if let position = recurrenceSetPosition,
               let weekday = recurrenceWeekdays?.first {
                return "\(recurrence.rawValue)\(L10n.RecurrenceDisplay.ordinal(position))\(L10n.RecurrenceDisplay.weekdayName(weekday))"
            }
            if let day = recurrenceDaysOfMonth?.first {
                return "\(recurrence.rawValue) \(day)日"
            }
        case .yearly:
            if let month = recurrenceMonthsOfYear?.first, let day = recurrenceDaysOfMonth?.first {
                return "\(recurrence.rawValue) \(month)月\(day)日"
            }
        default:
            break
        }
        return recurrence.rawValue
    }

    /// 获取优先级枚举值
    var priority: Priority {
        get {
            switch priorityValue {
            case 1...4:
                return .high
            case 5:
                return .medium
            case 6...9:
                return .low
            default:
                return .none
            }
        }
        set {
            priorityValue = newValue.rawValue
        }
    }
    
    /// 格式化的日期显示
    var formattedDueDate: String {
        guard let date = dueDate else { return L10n.Common.notSet }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if isAllDay {
            formatter.dateFormat = "yyyy年M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// 格式化的时间范围显示（用于日历事件）
    var formattedDateRange: String {
        guard let start = dueDate else { return L10n.Common.notSet }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if isAllDay {
            formatter.dateFormat = "M月d日"
            if let end = endDate {
                return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
            return formatter.string(from: start)
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
            if let end = endDate {
                let endFormatter = DateFormatter()
                endFormatter.locale = Locale(identifier: "zh_CN")
                // 如果是同一天，只显示结束时间
                if Calendar.current.isDate(start, inSameDayAs: end) {
                    endFormatter.dateFormat = "HH:mm"
                } else {
                    endFormatter.dateFormat = "M月d日 HH:mm"
                }
                return "\(formatter.string(from: start)) - \(endFormatter.string(from: end))"
            }
            return formatter.string(from: start)
        }
    }
}

/// 创建历史记录模型
/// 用于存储已创建的事项记录
struct CreatedItemRecord: Identifiable, Codable {
    /// 当前记录格式版本，用于未来字段迁移
    static let currentVersion = 1

    let id: UUID
    let item: ParsedItem
    let createdAt: Date
    let isSuccess: Bool
    let errorMessage: String?
    let calendarItemIdentifier: String?
    var undoneAt: Date?
    let version: Int

    var isUndone: Bool { undoneAt != nil }

    private enum CodingKeys: String, CodingKey {
        case id, item, createdAt, isSuccess, errorMessage, calendarItemIdentifier, undoneAt, version
    }

    init(
        item: ParsedItem,
        isSuccess: Bool = true,
        errorMessage: String? = nil,
        calendarItemIdentifier: String? = nil,
        undoneAt: Date? = nil,
        version: Int = CreatedItemRecord.currentVersion
    ) {
        self.id = UUID()
        self.item = item
        self.createdAt = Date()
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.calendarItemIdentifier = calendarItemIdentifier
        self.undoneAt = undoneAt
        self.version = version
    }

    /// 兼容历史持久化数据：缺少 version 等新增可选字段时回退默认值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        item = try container.decode(ParsedItem.self, forKey: .item)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        calendarItemIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarItemIdentifier)
        undoneAt = try container.decodeIfPresent(Date.self, forKey: .undoneAt)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    }
}
