//
//  NLPParser.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  原生自然语言解析器
//  使用 NSDataDetector 与中英文规则识别日期、时间、重复、优先级与备注
//

import Foundation

/// 原生自然语言解析器
/// 中文：NSDataDetector + 关键词/正则规则；英文：关键词/正则规则
class NLPParser: ItemParser {

    // MARK: - ItemParser 协议属性

    var name: String { L10n.Parser.nativeName }
    var description: String { L10n.Parser.nativeDescription }
    var requiresNetwork: Bool { false }

    // MARK: - 中文关键词

    /// 提醒事项关键词（用于判断类型）
    private let reminderKeywords = ["提醒", "记得", "别忘了", "别忘记", "待办", "任务"]

    /// 日历事件关键词
    private let calendarKeywords = ["会议", "开会", "约会", "出差", "活动", "预约", "安排", "日程", "聚会", "面试"]

    /// 重复周期关键词映射
    private let recurrenceKeywords: [String: RecurrenceRule] = [
        "每天": .daily,
        "每日": .daily,
        "天天": .daily,
        "工作日": .weekdays,
        "每个工作日": .weekdays,
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

    /// 星期关键词（Foundation weekday 值，仅用于标题清洗）
    private let weekdayKeywords: [String: Int] = [
        "周一": 2, "星期一": 2, "礼拜一": 2,
        "周二": 3, "星期二": 3, "礼拜二": 3,
        "周三": 4, "星期三": 4, "礼拜三": 4,
        "周四": 5, "星期四": 5, "礼拜四": 5,
        "周五": 6, "星期五": 6, "礼拜五": 6,
        "周六": 7, "星期六": 7, "礼拜六": 7,
        "周日": 1, "星期日": 1, "星期天": 1, "礼拜天": 1
    ]

    /// 中文星期字 → ISO 星期（1=周一 … 7=周日）
    private let chineseDayISO: [String: Int] = ["一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7]

    /// 中文数字 → 数值（相对时长用）
    private let chineseNumeralValues: [String: Double] = [
        "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9, "十": 10
    ]

    // MARK: - 英文关键词

    private let englishReminderKeywords = ["remind", "remember to", "don't forget", "dont forget", "todo", "task"]

    private let englishCalendarKeywords = [
        "meeting", "appointment", "interview", "party", "gathering",
        "conference", "schedule", "trip", "event"
    ]

    /// 英文相对日期关键词（匹配前统一转小写）
    private let englishRelativeDateKeywords: [(keyword: String, daysOffset: Int)] = [
        ("day after tomorrow", 2),
        ("today", 0),
        ("tonight", 0),
        ("tomorrow", 1)
    ]

    /// 英文星期全名 → ISO 星期
    private let englishWeekdayISO: [String: Int] = [
        "monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4,
        "friday": 5, "saturday": 6, "sunday": 7
    ]

    /// 英文月份缩写 → 月号
    private let englishMonthNumbers: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    private static let englishMonthPattern =
        #"(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"#

    /// 英文重复周期模式（顺序敏感：具体的在前，泛化的在后）
    private let englishRecurrencePatterns: [(pattern: String, rule: RecurrenceRule)] = [
        (#"every\s+\d+\s*days?"#, .daily),
        (#"every\s+\d+\s*weeks?"#, .weekly),
        (#"every\s+\d+\s*months?"#, .monthly),
        (#"every\s+\d+\s*years?"#, .yearly),
        (#"every\s+(?:other\s+week|2\s+weeks?)|\bbiweekly\b|\bfortnightly\b"#, .biweekly),
        (#"every\s+weekday|on\s+weekdays|\bweekdays\b"#, .weekdays),
        (#"every\s+(?:week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|each\s+week|\bweekly\b"#, .weekly),
        (#"every\s+day|each\s+day|\bdaily\b"#, .daily),
        (#"every\s+month|each\s+month|\bmonthly\b"#, .monthly),
        (#"every\s+year|each\s+year|\byearly\b|\bannually\b"#, .yearly)
    ]

    // MARK: - 解析方法

    func parse(_ input: String) async throws -> [ParsedItem] {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw ParserError.emptyInput
        }

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
    private func splitIntoSegments(_ text: String) -> [String] {
        // 分号和换行明确分隔事项；逗号只有在两侧都像完整日程时才分隔。
        let strongSeparators = CharacterSet(charactersIn: "；;\n")
        let primarySegments = text.components(separatedBy: strongSeparators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let segments = primarySegments.flatMap { segment -> [String] in
            let commaParts = segment.components(separatedBy: CharacterSet(charactersIn: "，,"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard commaParts.count > 1,
                  commaParts.allSatisfy(containsSchedulingMarker) else {
                return [segment]
            }
            return commaParts
        }

        return segments.isEmpty ? [text] : segments
    }

    private func containsSchedulingMarker(_ text: String) -> Bool {
        let lowered = text.lowercased()

        let chineseKeywords = reminderKeywords
            + calendarKeywords
            + Array(relativeDateKeywords.keys)
            + Array(weekdayKeywords.keys)
            + Array(recurrenceKeywords.keys)
        if chineseKeywords.contains(where: { text.contains($0) }) {
            return true
        }

        let englishKeywords = englishReminderKeywords
            + englishCalendarKeywords.filter { $0 != "event" }
            + ["tomorrow", "today", "tonight", "every"]
        if englishKeywords.contains(where: { lowered.contains($0) }) {
            return true
        }

        let pattern = #"\d{1,2}月\d{1,2}[日号]|\d{1,2}[:点时]\d{0,2}|(上午|下午|早上|晚上|中午)|(分钟|小时|钟头|天|日)后|\d\s*(a\.?m\.?|p\.?m\.?)|in\s+\d+\s*(min|hour|day)"#
        return text.range(of: pattern, options: .regularExpression) != nil
            || lowered.range(of: #"tomorrow|today|tonight|every\s+\w+"#, options: .regularExpression) != nil
    }

    /// 解析单个文本片段
    private func parseSingleSegment(_ segment: String, originalText: String) -> ParsedItem? {
        let trimmedInput = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return nil
        }

        // 重复规则（含月内日期等细节），先于日期提取以便推导种子日期
        let recurrence = extractRecurrence(from: trimmedInput)
        let recurrenceInterval = extractRecurrenceInterval(from: trimmedInput)
        let details = extractRecurrenceDetails(from: trimmedInput)
        var recurrenceWeekdays = extractRecurrenceWeekdays(from: trimmedInput, recurrence: recurrence)
        if details.setPosition != nil, let weekday = details.positionWeekday {
            recurrenceWeekdays = [weekday]
        }

        // 提取日期时间
        let (dueDate, endDate, isAllDay) = extractDates(
            from: trimmedInput,
            recurrence: recurrence,
            details: details
        )

        // 判断事项类型
        let type = determineItemType(from: trimmedInput)
        let alertSettings = extractAlertSettings(from: trimmedInput, type: type, isAllDay: isAllDay)

        // 提取优先级、备注和标题
        let priorityValue = extractPriority(from: trimmedInput)
        var (title, notes) = extractTitleAndNotes(from: trimmedInput, type: type)
        if title.isEmpty, let extractedNotes = notes, dueDate == nil {
            // 整段被当作备注（如 "(买牛奶)"）时回退为标题
            title = extractedNotes
            notes = nil
        }

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

        let item = ParsedItem(
            type: type,
            title: title.isEmpty ? trimmedInput : title,
            notes: notes,
            dueDate: dueDate,
            endDate: finalEndDate,
            isAllDay: isAllDay,
            priorityValue: priorityValue,
            recurrence: recurrence,
            recurrenceInterval: recurrenceInterval,
            recurrenceWeekdays: recurrenceWeekdays,
            recurrenceDaysOfMonth: details.daysOfMonth.map { [$0] },
            recurrenceMonthsOfYear: details.monthsOfYear.map { [$0] },
            recurrenceSetPosition: details.setPosition,
            alertEnabled: alertSettings.enabled,
            alertOffsetMinutes: alertSettings.offsetMinutes,
            confidence: confidence,
            originalText: trimmedInput
        )
        return ScheduleNormalizer.normalize(item)
    }

    // MARK: - 日期提取

    /// 从文本中提取日期时间
    private func extractDates(
        from text: String,
        recurrence: RecurrenceRule,
        details: RecurrenceDetails
    ) -> (dueDate: Date?, endDate: Date?, isAllDay: Bool) {
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
                        if match.duration > 0 {
                            endDate = date.addingTimeInterval(match.duration)
                        }
                        // 判断是否为全天事件（如果检测到具体时间则不是全天）
                        if match.timeZone != nil {
                            isAllDay = false
                        }
                    } else if endDate == nil {
                        endDate = date
                    }
                }
            }
        }

        // NSDataDetector 没有检测到日期时，依次尝试规则解析
        if dueDate == nil {
            dueDate = parseRelativeDate(from: text)
        }

        // 相对时长："30分钟后"、"两小时后"、"in 30 minutes"
        if dueDate == nil {
            dueDate = parseRelativeDuration(from: text)
            if dueDate != nil {
                isAllDay = false
            }
        }

        // "每月15号"：推导下一次发生日期作为种子
        if dueDate == nil,
           recurrence == .monthly,
           let day = details.daysOfMonth {
            dueDate = nextDate(ofMonthDay: day)
        }

        // 尝试解析时间。只有钟点没有日期时，使用最近的未来时刻。
        if let parsedTime = parseTime(from: text) {
            let calendar = Calendar.current
            let hadExplicitDate = dueDate != nil
            let baseDate = dueDate ?? calendar.startOfDay(for: Date())
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            dueDate = calendar.date(from: components)
            if !hadExplicitDate, let date = dueDate, date <= Date() {
                dueDate = calendar.date(byAdding: .day, value: 1, to: date)
            }
            isAllDay = false
        }

        return (dueDate, endDate, isAllDay)
    }

    /// 解析相对日期与固定格式日期（中英文）
    private func parseRelativeDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lowered = text.lowercased()

        // 中文相对日期：今天/明天/后天/大后天
        for (keyword, daysOffset) in relativeDateKeywords {
            if text.contains(keyword) {
                return calendar.date(byAdding: .day, value: daysOffset, to: today)
            }
        }

        // 中文日期格式：2027年3月5日 / 明年3月5日 / 3月5日
        if let date = parseChineseDateFormat(from: text) {
            return date
        }

        // 下个月X日/号
        if let date = parseNextMonthDay(from: text) {
            return date
        }

        // 月底/月末（含下个月底）
        if let date = parseEndOfMonth(from: text) {
            return date
        }

        // 英文相对日期
        for (keyword, daysOffset) in englishRelativeDateKeywords {
            if lowered.contains(keyword) {
                return calendar.date(byAdding: .day, value: daysOffset, to: today)
            }
        }

        // 中文星期：下周三 / 这周五 / 周一 / 每周五
        if let match = matchChineseWeekday(in: text) {
            return nextDate(ofISOWeekday: match.isoWeekday, forceNextWeek: match.forceNextWeek)
        }

        // 英文星期：next monday / every monday / on friday
        if let isoWeekday = matchEnglishWeekday(in: lowered) {
            return nextDate(ofISOWeekday: isoWeekday, forceNextWeek: false)
        }

        // 英文月份日期：March 5 / Mar 5th / 5th of March
        if let date = parseEnglishMonthDay(from: lowered) {
            return date
        }

        return nil
    }

    /// 解析中文日期格式（如：2027年3月5日、明年3月5日、1月25日）
    private func parseChineseDateFormat(from text: String) -> Date? {
        let calendar = Calendar.current

        // 带显式年份：2027年3月5日（已过也不顺延，尊重用户输入）
        if let date = matchChineseDate(
            text,
            pattern: #"(?:今年|明年)?\s*(\d{2,4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?"#
        ) { values in
            guard values.count == 3 else { return nil }
            var year = values[0]
            if text.contains("明年") {
                year = calendar.component(.year, from: Date()) + 1
            } else if text.contains("今年") {
                year = calendar.component(.year, from: Date())
            }
            var components = DateComponents()
            components.year = year
            components.month = values[1]
            components.day = values[2]
            return components
        } {
            return date
        }

        // 无年份：3月5日（已过则顺延到明年）
        if let date = matchChineseDate(
            text,
            pattern: #"(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]"#
        ) { values in
            guard values.count == 2 else { return nil }
            var components = calendar.dateComponents([.year], from: Date())
            components.month = values[0]
            components.day = values[1]
            return components
        } {
            if date < calendar.startOfDay(for: Date()) {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.year = (components.year ?? 0) + 1
                return calendar.date(from: components)
            }
            return date
        }

        return nil
    }

    /// 中文日期匹配辅助：提取所有数字捕获组后交给 build 构造日期组件
    private func matchChineseDate(
        _ text: String,
        pattern: String,
        build: ([Int]) -> DateComponents?
    ) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        let nsText = text as NSString
        var values: [Int] = []
        for group in 1..<match.numberOfRanges {
            let range = match.range(at: group)
            guard range.location != NSNotFound,
                  let value = Int(nsText.substring(with: range)) else {
                return nil
            }
            values.append(value)
        }
        guard let components = build(values) else { return nil }
        return Calendar.current.date(from: components)
    }

    /// "下个月15号"
    private func parseNextMonthDay(from text: String) -> Date? {
        guard let match = firstMatch(
            text,
            pattern: #"下\s*个?\s*月\s*(\d{1,2})\s*[日号]"#
        ) else {
            return nil
        }
        let day = match.int(0)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.month = (components.month ?? 1) + 1
        if (components.month ?? 1) > 12 {
            components.month = 1
            components.year = (components.year ?? 2026) + 1
        }
        let tentative = calendar.date(from: components) ?? Date()
        let maxDay = calendar.range(of: .day, in: .month, for: tentative)?.count ?? 31
        components.day = min(day, maxDay)
        return calendar.date(from: components)
    }

    /// 月底/月末（含下个月底、本月底）
    private func parseEndOfMonth(from text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"(下个)?月[底末]"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        let nsText = text as NSString
        let isNextMonth = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .month, value: isNextMonth ? 1 : 0, to: Date()) ?? Date()
        guard let dayRange = calendar.range(of: .day, in: .month, for: base) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = dayRange.count
        return calendar.date(from: components)
    }

    /// 中文星期匹配结果
    private struct WeekdayMatch {
        let isoWeekday: Int
        let range: NSRange   // 完整匹配范围（含"下/这/本/每"前缀）
        let prefix: String   // 下/这/本/每，或空串
    }

    /// 扫描文本中的中文星期词（含"日本"误判防护）
    private func scanChineseWeekdays(in text: String) -> [WeekdayMatch] {
        guard let regex = try? NSRegularExpression(pattern: #"(下|这|本|每)?(?:周|星期|礼拜)([一二三四五六日天])"#) else {
            return []
        }
        let nsText = text as NSString
        var results: [WeekdayMatch] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.range(at: 2).location != NSNotFound else { continue }
            let dayChar = nsText.substring(with: match.range(at: 2))

            // "下周日本旅游"：日/天 后紧跟"本"视为国名，跳过该匹配避免误判为星期日
            let afterMatch = match.range.location + match.range.length
            if (dayChar == "日" || dayChar == "天"), afterMatch < nsText.length,
               nsText.substring(with: NSRange(location: afterMatch, length: 1)) == "本" {
                continue
            }

            guard let isoWeekday = chineseDayISO[dayChar] else { continue }
            let prefix = match.range(at: 1).location == NSNotFound
                ? ""
                : nsText.substring(with: match.range(at: 1))
            results.append(WeekdayMatch(isoWeekday: isoWeekday, range: match.range, prefix: prefix))
        }
        return results
    }

    /// 匹配中文星期词（下周三/这周五/周一/每周五），返回首个有效匹配
    private func matchChineseWeekday(in text: String) -> (isoWeekday: Int, forceNextWeek: Bool)? {
        guard let first = scanChineseWeekdays(in: text).first else { return nil }
        return (first.isoWeekday, first.prefix == "下")
    }

    /// 匹配英文星期名（返回 ISO 星期）
    private func matchEnglishWeekday(in loweredText: String) -> Int? {
        for (name, isoWeekday) in englishWeekdayISO where loweredText.contains(name) {
            return isoWeekday
        }
        return nil
    }

    /// 英文月份日期："march 5" / "mar 5th" / "5th of march"
    private func parseEnglishMonthDay(from loweredText: String) -> Date? {
        let monthPattern = Self.englishMonthPattern

        // "March 5" / "Mar 5th"
        if let match = firstMatch(
            loweredText,
            pattern: #"\b\#(monthPattern)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b"#
        ) {
            let month = englishMonthNumbers[String(match.captures[0].prefix(3))] ?? 0
            let day = match.int(1)
            if let date = nextAnnualDate(month: month, day: day) { return date }
        }

        // "5th of March"
        if let match = firstMatch(
            loweredText,
            pattern: #"\b(\d{1,2})(?:st|nd|rd|th)?\s+of\s+\#(monthPattern)\.?\b"#
        ) {
            let day = match.int(0)
            let month = englishMonthNumbers[String(match.captures[1].prefix(3))] ?? 0
            if let date = nextAnnualDate(month: month, day: day) { return date }
        }

        return nil
    }

    /// 某月某日在今年已过则顺延到明年
    private func nextAnnualDate(month: Int, day: Int, calendar: Calendar = .current) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = calendar.dateComponents([.year], from: Date())
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        if date < calendar.startOfDay(for: Date()) {
            components.year = (components.year ?? 0) + 1
            return calendar.date(from: components)
        }
        return date
    }

    /// 下一个指定 ISO 星期几的日期
    private func nextDate(ofISOWeekday isoWeekday: Int, forceNextWeek: Bool, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: Date())
        let currentFoundationWeekday = calendar.component(.weekday, from: today)
        let currentISOWeekday = ((currentFoundationWeekday + 5) % 7) + 1

        let daysToAdd: Int
        if forceNextWeek {
            let daysUntilNextMonday = 8 - currentISOWeekday
            daysToAdd = daysUntilNextMonday + isoWeekday - 1
        } else {
            let delta = (isoWeekday - currentISOWeekday + 7) % 7
            daysToAdd = delta == 0 ? 7 : delta
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: today)
    }

    /// 下一次某月内日期（"每月15号"种子日期）
    private func nextDate(ofMonthDay day: Int, calendar: Calendar = .current) -> Date? {
        guard (1...31).contains(day) else { return nil }
        let today = calendar.startOfDay(for: Date())

        var components = calendar.dateComponents([.year, .month], from: today)
        let currentDay = calendar.component(.day, from: today)
        if day >= currentDay {
            components.day = day
            if let date = calendar.date(from: components), date >= today {
                return date
            }
        }

        // 本月已过，取下个月（超出月末天数时取月末）
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) else { return nil }
        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        let maxDay = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 31
        nextComponents.day = min(day, maxDay)
        return calendar.date(from: nextComponents)
    }

    /// 相对时长："30分钟后" / "半小时后" / "两小时后" / "3天后" / "in 30 minutes" / "2 hours later"
    private func parseRelativeDuration(from text: String) -> Date? {
        let calendar = Calendar.current

        // 中文：数值/中文数字/半 + 可选"个半" + 单位 + 后
        if let match = firstMatch(
            text,
            pattern: #"(\d+|[一两二三四五六七八九十]|半)(个半)?(分钟|分|小时|钟头|天|日)后"#
        ) {
            let valueText = match.captures[0]
            let hasHalfSuffix = match.captures.count > 1 && !match.captures[1].isEmpty
            let unit = match.captures[2]

            var value: Double
            if let digits = Double(valueText) {
                value = digits
            } else if valueText == "半" {
                value = 0.5
            } else {
                value = chineseNumeralValues[valueText] ?? 0
            }
            if hasHalfSuffix { value += 0.5 }

            let seconds: TimeInterval
            switch unit {
            case "分钟", "分": seconds = value * 60
            case "小时", "钟头": seconds = value * 3600
            default: seconds = value * 86400 // 天/日
            }
            return Date().addingTimeInterval(seconds)
        }

        // 英文："in 30 minutes" / "in half an hour" / "2 hours later / from now"
        let lowered = text.lowercased()
        let englishPatterns = [
            #"\bin\s+(\d+|half\s+an?|an?)\s+(min(?:ute)?s?|hours?|days?|weeks?)"#,
            #"\b(\d+|half\s+an?)\s+(min(?:ute)?s?|hours?|days?|weeks?)\s+(?:later|from\s+now)"#
        ]
        for pattern in englishPatterns {
            if let match = firstMatch(lowered, pattern: pattern, caseInsensitive: true) {
                let valueText = match.captures[0].trimmingCharacters(in: .whitespaces)
                let unit = match.captures[1]

                var value: Double
                if let digits = Double(valueText) {
                    value = digits
                } else if valueText.hasPrefix("half") {
                    value = 0.5
                } else {
                    value = 1 // a / an
                }

                let seconds: TimeInterval
                if unit.hasPrefix("min") {
                    seconds = value * 60
                } else if unit.hasPrefix("hour") {
                    seconds = value * 3600
                } else if unit.hasPrefix("day") {
                    seconds = value * 86400
                } else {
                    seconds = value * 86400 * 7 // week
                }
                _ = calendar // 保持与中文分支一致的计算方式
                return Date().addingTimeInterval(seconds)
            }
        }

        return nil
    }

    /// 解析时间（如：下午3点、15:00、9am、3pm、noon）
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

        // 匹配英文 "9am" / "3:30pm"
        if hour == nil {
            if let match = firstMatch(
                text,
                pattern: #"\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\b"#,
                caseInsensitive: true
            ) {
                hour = match.int(0)
                if !match.captures[1].isEmpty {
                    minute = match.int(1)
                }
                if match.captures[2].lowercased().hasPrefix("p"), let h = hour, h < 12 {
                    hour = h + 12
                }
            }
        }

        // 匹配英文 "at 5 o'clock"（需上下文有 morning/afternoon/evening 才调整时段）
        if hour == nil {
            if let match = firstMatch(
                text,
                pattern: #"\bat\s+(\d{1,2})\s*o'?clock"#,
                caseInsensitive: true
            ) {
                hour = match.int(0)
                let lowered = text.lowercased()
                if lowered.contains("afternoon") || lowered.contains("evening"), let h = hour, h < 12 {
                    hour = h + 12
                }
            }
        }

        // noon / midnight
        if hour == nil {
            let lowered = text.lowercased()
            if let range = lowered.range(of: #"\bnoon\b"#, options: .regularExpression) {
                _ = range
                hour = 12
            } else if lowered.range(of: #"\bmidnight\b"#, options: .regularExpression) != nil {
                hour = 0
            }
        }

        guard let h = hour else { return nil }
        // 无效钟点视为没有时间
        guard (0...23).contains(h), (0...59).contains(minute) else { return nil }

        var components = DateComponents()
        components.hour = h
        components.minute = minute

        return calendar.date(from: components)    }

    // MARK: - 重复周期提取

    /// 从文本中提取重复周期
    private func extractRecurrence(from text: String) -> RecurrenceRule {
        let lowered = text.lowercased()

        // 中文关键词
        for (keyword, rule) in recurrenceKeywords {
            if text.contains(keyword) {
                return rule
            }
        }

        // 英文模式
        for (pattern, rule) in englishRecurrencePatterns {
            if lowered.range(of: pattern, options: .regularExpression) != nil {
                return rule
            }
        }

        if text.range(of: #"每\s*\d+\s*天"#, options: .regularExpression) != nil { return .daily }
        if text.range(of: #"每\s*\d+\s*(周|星期|礼拜)"#, options: .regularExpression) != nil { return .weekly }
        if text.range(of: #"每\s*\d+\s*(月|个月)"#, options: .regularExpression) != nil { return .monthly }
        return .none
    }

    private func extractRecurrenceInterval(from text: String) -> Int? {
        // 中文：每 N 天/周/月/年
        let pattern = #"每\s*(\d+)\s*(天|周|星期|礼拜|月|个月|年)"#
        if let match = firstMatch(text, pattern: pattern) {
            return max(match.int(0), 1)
        }

        // 英文：every N days/weeks/months/years
        if let match = firstMatch(text, pattern: #"every\s+(\d+)\s+(?:days?|weeks?|months?|years?)"#, caseInsensitive: true) {
            return max(match.int(0), 1)
        }

        return nil
    }

    private func extractRecurrenceWeekdays(from text: String, recurrence: RecurrenceRule) -> [Int]? {
        if recurrence == .weekdays { return [1, 2, 3, 4, 5] }
        guard recurrence == .weekly || recurrence == .biweekly || recurrence == .monthly else { return nil }

        var values = scanChineseWeekdays(in: text).map(\.isoWeekday)

        // 英文星期名
        let lowered = text.lowercased()
        for (name, isoWeekday) in englishWeekdayISO {
            if lowered.contains(name) {
                values.append(isoWeekday)
            }
        }

        let unique = Array(Set(values)).sorted()
        return unique.isEmpty ? nil : unique
    }

    // MARK: - 重复细节（每月X日 / 每年X月X日 / 每月第N个星期X）

    private struct RecurrenceDetails {
        var daysOfMonth: Int? = nil
        var monthsOfYear: Int? = nil
        var setPosition: Int? = nil
        var positionWeekday: Int? = nil
    }

    private func extractRecurrenceDetails(from text: String) -> RecurrenceDetails {
        var details = RecurrenceDetails()
        let lowered = text.lowercased()
        let monthPattern = Self.englishMonthPattern

        // 中文：每月15号 / 每月15日
        if let match = firstMatch(text, pattern: #"每\s*个?\s*月\s*(\d{1,2})\s*[日号]"#) {
            details.daysOfMonth = match.int(0)
            return details
        }

        // 中文：每年3月5日
        if let match = firstMatch(text, pattern: #"每\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?"#) {
            details.monthsOfYear = match.int(0)
            details.daysOfMonth = match.int(1)
            return details
        }

        // 中文：每月最后一个周五 / 每月第三个周一（"最后"后可带"一个"）
        if let match = firstMatch(
            text,
            pattern: #"每\s*个?\s*月\s*(最后(?:一个)?|第[一二三四1-4]\s*个?)\s*(?:周|星期|礼拜)([一二三四五六日天])"#
        ) {
            let positionText = match.captures[0]
            let dayChar = match.captures[1]
            if let weekday = chineseDayISO[dayChar] {
                details.positionWeekday = weekday
                if positionText.contains("最后") {
                    details.setPosition = -1
                } else if positionText.contains("一") || positionText.contains("1") {
                    details.setPosition = 1
                } else if positionText.contains("二") || positionText.contains("2") {
                    details.setPosition = 2
                } else if positionText.contains("三") || positionText.contains("3") {
                    details.setPosition = 3
                } else if positionText.contains("四") || positionText.contains("4") {
                    details.setPosition = 4
                } else {
                    details.setPosition = -1
                }
            }
            return details
        }

        // 英文：the 15th of every month / every month on the 15th
        let englishMonthDayPatterns = [
            #"(?:on\s+|the\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+of\s+(?:every|each)\s+month"#,
            #"every\s+month\s+(?:on\s+the\s+)?(\d{1,2})(?:st|nd|rd|th)?"#
        ]
        for pattern in englishMonthDayPatterns {
            if let match = firstMatch(lowered, pattern: pattern) {
                details.daysOfMonth = match.int(0)
                return details
            }
        }

        // 英文：every year on March 5 / March 5 every year
        let englishYearlyPatterns = [
            #"every\s+year\s+(?:on\s+)?\#(monthPattern)\.?\s+(\d{1,2})(?:st|nd|rd|th)?"#,
            #"\#(monthPattern)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\s+(?:every|each)\s+year"#
        ]
        for pattern in englishYearlyPatterns {
            if let match = firstMatch(lowered, pattern: pattern) {
                details.monthsOfYear = englishMonthNumbers[String(match.captures[0].prefix(3))]
                details.daysOfMonth = match.int(1)
                if details.monthsOfYear != nil { return details }
            }
        }

        // 英文：the last friday of every month / every month on the second tuesday
        let ordinalWords: [String: Int] = ["first": 1, "second": 2, "third": 3, "fourth": 4, "last": -1]
        let englishPositionPatterns = [
            #"the\s+(first|second|third|fourth|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+of\s+(?:every|each)\s+month"#,
            #"every\s+month\s+(?:on\s+)?the\s+(first|second|third|fourth|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        ]
        for pattern in englishPositionPatterns {
            if let match = firstMatch(lowered, pattern: pattern) {
                details.setPosition = ordinalWords[match.captures[0]]
                details.positionWeekday = englishWeekdayISO[match.captures[1]]
                if details.setPosition != nil, details.positionWeekday != nil { return details }
            }
        }

        return details
    }

    // MARK: - 优先级提取

    /// 提取优先级：！！！/紧急 → 高(1)；！！/重要 → 中(5)；！ → 低(9)
    private func extractPriority(from text: String) -> Int {
        // 连续感叹号（全/半角）取最长串
        if let regex = try? NSRegularExpression(pattern: "[!！]+") {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            if let longest = matches.map({ $0.range.length }).max() {
                switch longest {
                case 1: return 9
                case 2: return 5
                default: return 1
                }
            }
        }

        let lowered = text.lowercased()
        if text.contains("紧急") || text.contains("加急")
            || lowered.range(of: #"\burgent\b|\bcritical\b"#, options: .regularExpression) != nil {
            return 1
        }
        if text.contains("重要") || lowered.range(of: #"\bimportant\b"#, options: .regularExpression) != nil {
            return 5
        }
        return 0
    }

    // MARK: - 提醒设置

    private func extractAlertSettings(
        from text: String,
        type: ItemType,
        isAllDay: Bool
    ) -> (enabled: Bool?, offsetMinutes: Int?) {
        if ["不提醒", "无需提醒", "不要通知", "无通知"].contains(where: { text.contains($0) }) {
            return (false, nil)
        }

        let pattern = #"提前\s*(\d+)\s*(分钟|分|小时|天)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let unitRange = Range(match.range(at: 2), in: text),
           let value = Int(text[valueRange]) {
            let unit = String(text[unitRange])
            let multiplier = unit == "天" ? 1440 : (unit == "小时" ? 60 : 1)
            return (true, -(value * multiplier))
        }

        if isAllDay { return (false, nil) }
        return (true, type == .calendar ? -15 : 0)
    }

    // MARK: - 类型判断

    private func determineItemType(from text: String) -> ItemType {
        let lowered = text.lowercased()

        // 日历关键词（中英文）优先
        for keyword in calendarKeywords {
            if text.contains(keyword) {
                return .calendar
            }
        }
        for keyword in englishCalendarKeywords {
            if lowered.range(of: #"\b\#(keyword)\b"#, options: .regularExpression) != nil {
                return .calendar
            }
        }

        // 提醒关键词
        for keyword in reminderKeywords {
            if text.contains(keyword) {
                return .reminder
            }
        }
        for keyword in englishReminderKeywords {
            if lowered.range(of: #"\b\#(keyword)\b"#, options: .regularExpression) != nil
                || lowered.contains(keyword) {
                return .reminder
            }
        }

        // 默认为提醒事项
        return .reminder
    }

    // MARK: - 标题与备注提取

    /// 提取标题（移除日期时间和关键词）与备注（括号内容 / "备注：xxx"）
    private func extractTitleAndNotes(from text: String, type: ItemType) -> (title: String, notes: String?) {
        var (notes, working) = extractNotes(from: text)
        var result = working

        // —— 中文清理 ——
        for keyword in relativeDateKeywords.keys {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        // 移除星期词（带"日本"误判防护，"下周日本旅游"中的"周日"不被误删）
        result = removeWeekdayTokens(from: result)

        let chineseTimePatterns = [
            #"(?:\d{2,4}\s*年)?\s*\d{1,2}\s*月\s*\d{1,2}\s*[日号]"#,
            #"\d{2,4}\s*年"#,
            "(上午|下午|早上|晚上|中午|凌晨|清晨|傍晚)",
            "\\d{1,2}\\s*[点时]\\d{0,2}\\s*分?",
            "\\d{1,2}:\\d{2}",
            "(?:\\d+|[一两二三四五六七八九十]|半)(?:个半)?(?:分钟|小时|钟头|天|日)后",
            "[!！]{1,3}",
            "每\\s*个?\\s*月\\s*\\d{1,2}\\s*[日号]",
            "每\\s*个?\\s*月\\s*(?:最后(?:一个)?|第[一二三四1-4]\\s*个?)\\s*(?:周|星期|礼拜)[一二三四五六日天]",
            "下\\s*个?\\s*月\\s*\\d{1,2}\\s*[日号]?",
            "下\\s*个?\\s*月",
            "(?:本|下个?)月[底末]"
        ]
        for pattern in chineseTimePatterns {
            removeRegexMatches(from: &result, pattern: pattern)
        }

        for keyword in recurrenceKeywords.keys {
            result = result.replacingOccurrences(of: keyword, with: "")
        }

        let removeKeywords = [
            "提醒我", "提醒", "记得", "别忘了", "别忘记",
            "下周", "下星期", "下礼拜", "这周", "这星期", "本周", "明年", "今年"
        ]
        for keyword in removeKeywords {
            result = result.replacingOccurrences(of: keyword, with: "")
        }

        // —— 英文清理（大小写不敏感）——
        let monthPattern = Self.englishMonthPattern
        let weekdayAlternation = "(?:mon|tues|wednes|thurs|fri|satur|sun)day"
        let englishRemovalPatterns = [
            #"(?:the\s+)?day\s+after\s+tomorrow"#,
            #"\btomorrow\b|\btoday\b|\btonight\b"#,
            #"(?:next|this|every|each|on|last)\s+\#(weekdayAlternation)\b"#,
            #"\b\#(weekdayAlternation)\b"#,
            #"every\s+(?:\d+\s+)?(?:other\s+\w+|\w+)|\bdaily\b|\bweekly\b|\bmonthly\b|\byearly\b|\bannually\b|\bweekdays\b|\bbiweekly\b|\bfortnightly\b"#,
            #"at\s+\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)?"#,
            #"\b\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)\b"#,
            #"\bat\s+\d{1,2}\s*o'?clock"#,
            #"\bnoon\b|\bmidnight\b"#,
            #"\b\#(monthPattern)\.?\s+\d{1,2}(?:st|nd|rd|th)?\b"#,
            #"\b(?:on\s+|the\s+)?\d{1,2}(?:st|nd|rd|th)?\s+of\s+(?:every|each)\s+month\b"#,
            #"every\s+month\s+(?:on\s+the\s+)?(?:\d{1,2}(?:st|nd|rd|th)?)?"#,
            #"every\s+year\b"#,
            #"in\s+\d+\s+(?:min(?:ute)?s?|hours?|days?|weeks?)\b"#,
            #"\b\d+\s+(?:min(?:ute)?s?|hours?|days?|weeks?)\s+(?:later|from\s+now)\b"#,
            #"remind\s+(?:me\s+)?(?:to\s+|about\s+|that\s+)?|remember\s+to|don'?t\s+forget(?:\s+to)?"#
        ]
        for pattern in englishRemovalPatterns {
            removeRegexMatches(from: &result, pattern: pattern, caseInsensitive: true)
        }

        // 清理多余空格
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " ，,;；"))

        if notes != nil && notes?.isEmpty == true {
            notes = nil
        }
        return (result, notes)
    }

    /// 移除文本中的中文星期词（跳过"日本"防护命中的部分）
    private func removeWeekdayTokens(from text: String) -> String {
        let matches = scanChineseWeekdays(in: text)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        // 从后往前删除，避免前面的删除使后面的 range 位移
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: "")
        }
        return mutable as String
    }

    /// 提取备注：括号内容（全/半角）与 "备注：xxx"；返回备注和移除后的文本
    private func extractNotes(from text: String) -> (notes: String?, cleanedText: String) {
        var notesParts: [String] = []
        var working = text

        // "备注：xxx" / "note: xxx"
        let keywordPattern = #"(?:备注|附注|note)\s*[:：]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: keywordPattern, options: [.caseInsensitive]) {
            let range = NSRange(working.startIndex..., in: working)
            if let match = regex.firstMatch(in: working, options: [], range: range) {
                let nsWorking = working as NSString
                let noteText = nsWorking.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !noteText.isEmpty {
                    notesParts.append(noteText)
                }
                working = (working as NSString).replacingCharacters(
                    in: match.range,
                    with: ""
                )
            }
        }

        // 括号内容（全/半角），逐个提取
        if let regex = try? NSRegularExpression(pattern: #"[（(]([^（）()]{1,200})[)）]"#) {
            let range = NSRange(working.startIndex..., in: working)
            let matches = regex.matches(in: working, options: [], range: range)
            for match in matches {
                let nsWorking = working as NSString
                let inner = nsWorking.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty {
                    notesParts.append(inner)
                }
            }
            if !matches.isEmpty {
                working = regex.stringByReplacingMatches(
                    in: working,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        return (notesParts.isEmpty ? nil : notesParts.joined(separator: "；"), working)
    }

    // MARK: - 正则辅助

    private struct RegexMatch {
        let fullMatch: String
        let captures: [String]

        /// 第 N 个捕获组的整数值（缺失或非数字时为 0）
        func int(_ index: Int) -> Int {
            guard index < captures.count, let value = Int(captures[index]) else { return 0 }
            return value
        }
    }

    private func firstMatch(
        _ text: String,
        pattern: String,
        caseInsensitive: Bool = false
    ) -> RegexMatch? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        let fullMatch = nsText.substring(with: match.range)
        var captures: [String] = []
        if match.numberOfRanges > 1 {
            for group in 1..<match.numberOfRanges {
                let range = match.range(at: group)
                captures.append(range.location == NSNotFound ? "" : nsText.substring(with: range))
            }
        }
        return RegexMatch(fullMatch: fullMatch, captures: captures)
    }

    private func removeRegexMatches(from text: inout String, pattern: String, caseInsensitive: Bool = false) {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(text.startIndex..., in: text)
        text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    // MARK: - 置信度计算

    /// 计算解析置信度
    private func calculateConfidence(hasDate: Bool, hasTitle: Bool, input: String) -> Double {
        var confidence = 0.5

        if hasDate {
            confidence += 0.3
        }
        if hasTitle {
            confidence += 0.2
        }
        if input.count > 10 {
            confidence += 0.1
        }

        return min(confidence, 1.0)
    }
}
