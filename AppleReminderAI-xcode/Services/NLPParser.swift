//
//  NLPParser.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  原生自然语言解析器
//  使用 NSDataDetector 和 NLTagger 进行日期和实体识别
//

import Foundation
import NaturalLanguage

/// 原生自然语言解析器
/// 使用系统内置的 NSDataDetector 提取日期，NLTagger 进行实体识别
class NLPParser: ItemParser {
    
    // MARK: - ItemParser 协议属性
    
    var name: String { "原生解析器" }
    var description: String { "使用系统内置的自然语言处理，离线可用" }
    var requiresNetwork: Bool { false }
    
    // MARK: - 私有属性
    
    /// 提醒事项关键词（用于判断类型）
    private let reminderKeywords = ["提醒", "记得", "别忘了", "别忘记", "todo", "待办", "任务"]
    
    /// 日历事件关键词
    private let calendarKeywords = ["会议", "开会", "约会", "出差", "活动", "预约", "安排", "日程", "聚会", "面试"]
    
    /// 重复周期关键词映射
    private let recurrenceKeywords: [String: RecurrenceRule] = [
        "每天": .daily,
        "每日": .daily,
        "天天": .daily,
        "每周": .weekly,
        "每星期": .weekly,
        "每礼拜": .weekly,
        "每两周": .biweekly,
        "隔周": .biweekly,
        "每月": .monthly,
        "每个月": .monthly,
        "每年": .yearly,
        "每年一次": .yearly
    ]
    
    /// 相对日期关键词
    private let relativeDateKeywords: [String: Int] = [
        "今天": 0,
        "明天": 1,
        "后天": 2,
        "大后天": 3
    ]
    
    /// 星期关键词
    private let weekdayKeywords: [String: Int] = [
        "周一": 2, "星期一": 2, "礼拜一": 2,
        "周二": 3, "星期二": 3, "礼拜二": 3,
        "周三": 4, "星期三": 4, "礼拜三": 4,
        "周四": 5, "星期四": 5, "礼拜四": 5,
        "周五": 6, "星期五": 6, "礼拜五": 6,
        "周六": 7, "星期六": 7, "礼拜六": 7,
        "周日": 1, "星期日": 1, "星期天": 1, "礼拜天": 1
    ]
    
    // MARK: - 解析方法
    
    func parse(_ input: String) async throws -> [ParsedItem] {
        // 检查输入是否为空
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw ParserError.emptyInput
        }
        
        // 按分隔符分割文本，支持解析多个事项
        let segments = splitIntoSegments(trimmedInput)
        var results: [ParsedItem] = []
        
        for segment in segments {
            if let item = parseSingleSegment(segment, originalText: trimmedInput) {
                results.append(item)
            }
        }
        
        return results
    }
    
    /// 将输入文本分割成多个片段
    /// - Parameter text: 原始输入文本
    /// - Returns: 分割后的文本片段数组
    private func splitIntoSegments(_ text: String) -> [String] {
        // 支持的分隔符：中文逗号、英文逗号、分号、换行符
        let separators = CharacterSet(charactersIn: "，,；;\n")
        let segments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 如果没有有效分割，返回原始文本
        return segments.isEmpty ? [text] : segments
    }
    
    /// 解析单个文本片段
    /// - Parameters:
    ///   - segment: 文本片段
    ///   - originalText: 原始完整输入文本
    /// - Returns: 解析后的事项，如果无法解析则返回 nil
    private func parseSingleSegment(_ segment: String, originalText: String) -> ParsedItem? {
        let trimmedInput = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return nil
        }
        
        // 提取日期时间
        let (dueDate, endDate, isAllDay) = extractDates(from: trimmedInput)
        
        // 提取重复周期
        let recurrence = extractRecurrence(from: trimmedInput)
        
        // 判断事项类型
        let type = determineItemType(from: trimmedInput)
        
        // 提取标题（移除日期和关键词）
        let title = extractTitle(from: trimmedInput, type: type)
        
        // 计算置信度
        let confidence = calculateConfidence(
            hasDate: dueDate != nil,
            hasTitle: !title.isEmpty,
            input: trimmedInput
        )
        
        // 如果既没有日期也没有有效标题，返回 nil
        guard !title.isEmpty || dueDate != nil else {
            return nil
        }
        
        // 如果是日历事件且没有明确识别出结束时间，默认加上 1 小时
        var finalEndDate = endDate
        if type == .calendar, let start = dueDate, finalEndDate == nil, !isAllDay {
            finalEndDate = start.addingTimeInterval(3600)
        }
        
        return ParsedItem(
            type: type,
            title: title.isEmpty ? trimmedInput : title,
            notes: nil,
            dueDate: dueDate,
            endDate: finalEndDate,
            isAllDay: isAllDay,
            priorityValue: 0,
            recurrence: recurrence,
            confidence: confidence,
            originalText: trimmedInput
        )
    }
    
    // MARK: - 日期提取
    
    /// 从文本中提取日期时间
    private func extractDates(from text: String) -> (dueDate: Date?, endDate: Date?, isAllDay: Bool) {
        var dueDate: Date?
        var endDate: Date?
        var isAllDay = true
        
        // 首先尝试使用 NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let date = match.date {
                    if dueDate == nil {
                        dueDate = date
                        // 检查是否有具体时间
                        if match.duration > 0 {
                            endDate = date.addingTimeInterval(match.duration)
                        }
                        // 判断是否为全天事件（如果检测到具体时间则不是全天）
                        if let timeZone = match.timeZone {
                            isAllDay = false
                            _ = timeZone // 使用变量避免警告
                        }
                    } else if endDate == nil {
                        endDate = date
                    }
                }
            }
        }
        
        // 如果 NSDataDetector 没有检测到日期，尝试手动解析
        if dueDate == nil {
            dueDate = parseRelativeDate(from: text)
        }
        
        // 尝试解析时间
        if let parsedTime = parseTime(from: text), let date = dueDate {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            dueDate = calendar.date(from: components)
            isAllDay = false
        }
        
        return (dueDate, endDate, isAllDay)
    }
    
    /// 解析相对日期（今天、明天、后天等）
    private func parseRelativeDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 检查相对日期关键词
        for (keyword, daysOffset) in relativeDateKeywords {
            if text.contains(keyword) {
                return calendar.date(byAdding: .day, value: daysOffset, to: today)
            }
        }
        
        // 检查"下周X"
        if text.contains("下周") || text.contains("下星期") || text.contains("下礼拜") {
            for (keyword, weekday) in weekdayKeywords {
                // 简化检查：只检查周几的部分
                let shortKeyword = String(keyword.suffix(1))
                if text.contains(shortKeyword) || text.contains(keyword) {
                    return getNextWeekday(weekday, fromNextWeek: true)
                }
            }
        }
        
        // 检查"这周X"或单独的"周X"
        for (keyword, weekday) in weekdayKeywords {
            if text.contains(keyword) {
                return getNextWeekday(weekday, fromNextWeek: false)
            }
        }
        
        // 尝试解析 "X月X日" 格式
        if let date = parseChineseDateFormat(from: text) {
            return date
        }
        
        return nil
    }
    
    /// 解析中文日期格式（如：1月25日）
    private func parseChineseDateFormat(from text: String) -> Date? {
        // 匹配格式：X月X日 或 X月X号
        let pattern = "(\\d{1,2})月(\\d{1,2})[日号]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        
        guard let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let month = Int(text[monthRange]),
              let day = Int(text[dayRange]) else {
            return nil
        }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: Date())
        components.month = month
        components.day = day
        
        guard let date = calendar.date(from: components) else {
            return nil
        }
        
        // 如果日期已过，则设为明年
        if date < Date() {
            components.year = (components.year ?? 0) + 1
            return calendar.date(from: components)
        }
        
        return date
    }
    
    /// 获取下一个指定星期几的日期
    private func getNextWeekday(_ targetWeekday: Int, fromNextWeek: Bool) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 || fromNextWeek {
            daysToAdd += 7
        }
        if fromNextWeek && daysToAdd <= 7 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))!
    }
    
    /// 解析时间（如：下午3点、15:00）
    private func parseTime(from text: String) -> Date? {
        let calendar = Calendar.current
        var hour: Int?
        var minute: Int = 0
        
        // 匹配 "X点X分" 格式
        let chinesePattern = "(上午|下午|早上|晚上|中午)?(\\d{1,2})[点时](\\d{1,2})?分?"
        if let regex = try? NSRegularExpression(pattern: chinesePattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                // 提取上午/下午
                var isPM = false
                if let periodRange = Range(match.range(at: 1), in: text) {
                    let period = String(text[periodRange])
                    isPM = ["下午", "晚上"].contains(period)
                }
                
                // 提取小时
                if let hourRange = Range(match.range(at: 2), in: text) {
                    hour = Int(text[hourRange])
                    if isPM, let h = hour, h < 12 {
                        hour = h + 12
                    }
                }
                
                // 提取分钟
                if match.range(at: 3).location != NSNotFound,
                   let minuteRange = Range(match.range(at: 3), in: text) {
                    minute = Int(text[minuteRange]) ?? 0
                }
            }
        }
        
        // 匹配 "HH:mm" 格式
        if hour == nil {
            let timePattern = "(\\d{1,2}):(\\d{2})"
            if let regex = try? NSRegularExpression(pattern: timePattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let hourRange = Range(match.range(at: 1), in: text),
                       let minuteRange = Range(match.range(at: 2), in: text) {
                        hour = Int(text[hourRange])
                        minute = Int(text[minuteRange]) ?? 0
                    }
                }
            }
        }
        
        guard let h = hour else { return nil }
        
        var components = DateComponents()
        components.hour = h
        components.minute = minute
        
        return calendar.date(from: components)
    }
    
    // MARK: - 重复周期提取
    
    /// 从文本中提取重复周期
    private func extractRecurrence(from text: String) -> RecurrenceRule {
        for (keyword, rule) in recurrenceKeywords {
            if text.contains(keyword) {
                return rule
            }
        }
        return .none
    }
    
    // MARK: - 类型判断
    
    /// 判断事项类型
    private func determineItemType(from text: String) -> ItemType {
        // 检查日历关键词
        for keyword in calendarKeywords {
            if text.contains(keyword) {
                return .calendar
            }
        }
        
        // 检查提醒关键词
        for keyword in reminderKeywords {
            if text.contains(keyword) {
                return .reminder
            }
        }
        
        // 默认为提醒事项
        return .reminder
    }
    
    // MARK: - 标题提取
    
    /// 提取标题（移除日期时间和关键词）
    private func extractTitle(from text: String, type: ItemType) -> String {
        var result = text
        
        // 移除日期相关词语
        for keyword in relativeDateKeywords.keys {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        
        // 移除星期相关词语
        for keyword in weekdayKeywords.keys {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        
        // 移除时间相关词语
        let timePatterns = [
            "上午|下午|早上|晚上|中午",
            "\\d{1,2}[点时]\\d{0,2}分?",
            "\\d{1,2}:\\d{2}",
            "\\d{1,2}月\\d{1,2}[日号]"
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }
        
        // 移除重复周期关键词
        for keyword in recurrenceKeywords.keys {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        
        // 移除提醒关键词
        let removeKeywords = ["提醒我", "提醒", "记得", "别忘了", "别忘记", "下周", "下星期", "下礼拜", "这周", "这星期"]
        for keyword in removeKeywords {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        
        // 清理多余空格
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return result
    }
    
    // MARK: - 置信度计算
    
    /// 计算解析置信度
    private func calculateConfidence(hasDate: Bool, hasTitle: Bool, input: String) -> Double {
        var confidence = 0.5  // 基础置信度
        
        if hasDate {
            confidence += 0.3  // 有日期加 0.3
        }
        
        if hasTitle {
            confidence += 0.2  // 有标题加 0.2
        }
        
        // 输入越长，可能包含更多信息
        if input.count > 10 {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
}
