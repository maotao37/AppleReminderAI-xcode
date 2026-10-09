import Testing
import Foundation
@testable import AppleReminderAICore

/// NLPParser 行为测试：新语法（优先级/备注/相对时长/重复细节/英文）与既有语法回归
@Suite("NLP 解析器")
struct NLPParserTests {
    private let parser = NLPParser()

    private func parseSingle(_ text: String) async throws -> ParsedItem {
        let items = try await parser.parse(text)
        #expect(items.count == 1, "期望解析出 1 个事项，实际 \(items.count) 个（输入：\(text)）")
        return items[0]
    }

    // MARK: - 优先级（#2）

    @Test func priorityTripleExclamationIsHigh() async throws {
        let item = try await parseSingle("明天提醒我交报告！！！")
        #expect(item.priorityValue == 1, "！！！应解析为高优先级(1)")
    }

    @Test func priorityDoubleExclamationIsMedium() async throws {
        let item = try await parseSingle("明天提醒我交报告！！")
        #expect(item.priorityValue == 5, "！！应解析为中优先级(5)")
    }

    @Test func priorityUrgentKeywordIsHigh() async throws {
        let item = try await parseSingle("紧急处理服务器故障")
        #expect(item.priorityValue == 1, "紧急应为高优先级")
    }

    @Test func priorityImportantKeywordIsMedium() async throws {
        let item = try await parseSingle("重要：给客户回电话")
        #expect(item.priorityValue == 5, "重要应为中优先级")
    }

    // MARK: - 备注（#2）

    @Test func notesFromParentheses() async throws {
        let item = try await parseSingle("明天开会（带笔记本电脑）")
        #expect(item.notes == "带笔记本电脑")
        #expect(!item.title.contains("带笔记本"), "括号内容不应留在标题里")
    }

    @Test func notesFromKeyword() async throws {
        let item = try await parseSingle("提醒我取快递 备注：到付")
        #expect(item.notes == "到付")
        #expect(item.title.contains("取快递"))
    }

    // MARK: - 相对时长（#3）

    @Test func relativeDurationMinutes() async throws {
        let before = Date()
        let item = try await parseSingle("30分钟后提醒我喝水")
        let after = Date()
        let dueDate = try #require(item.dueDate, "应解析出相对时间")
        #expect(dueDate.timeIntervalSince(before) >= 29 * 60, "应至少在 29 分钟后")
        #expect(dueDate.timeIntervalSince(after) <= 31 * 60, "应至多在 31 分钟后")
        #expect(item.title.contains("喝水"))
        #expect(!item.isAllDay)
    }

    @Test func relativeDurationHalfHour() async throws {
        let item = try await parseSingle("半小时后提醒我喝水")
        let dueDate = try #require(item.dueDate)
        #expect(abs(dueDate.timeIntervalSinceNow - 30 * 60) < 120)
    }

    @Test func relativeDurationChineseNumeralHours() async throws {
        let item = try await parseSingle("两小时后提醒我复查构建")
        let dueDate = try #require(item.dueDate)
        #expect(abs(dueDate.timeIntervalSinceNow - 2 * 3600) < 120)
    }

    // MARK: - 带年份 / 下个月 / 月底（#8）

    @Test func explicitYearDate() async throws {
        let item = try await parseSingle("2027年3月5日交年度总结")
        let dueDate = try #require(item.dueDate)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        #expect(components.year == 2027, "显式年份不应被替换")
        #expect(components.month == 3)
        #expect(components.day == 5)
    }

    @Test func nextMonthDay() async throws {
        let item = try await parseSingle("下个月15号还信用卡")
        let dueDate = try #require(item.dueDate)
        let calendar = Calendar.current
        let nextMonthDate = try #require(calendar.date(byAdding: .month, value: 1, to: Date()))
        let components = calendar.dateComponents([.month, .day], from: dueDate)
        #expect(components.month == calendar.component(.month, from: nextMonthDate))
        #expect(components.day == 15)
        #expect(item.title.contains("信用卡"))
    }

    @Test func endOfMonth() async throws {
        let item = try await parseSingle("月底完成报销")
        let dueDate = try #require(item.dueDate)
        let calendar = Calendar.current
        let range = try #require(calendar.range(of: .day, in: .month, for: Date()))
        #expect(calendar.component(.day, from: dueDate) == range.count, "月底应为当月最后一天")
    }

    // MARK: - 下周X 误判修复（#14）

    @Test func nextWeekJapanIsNotParsedAsSunday() async throws {
        let item = try await parseSingle("下周日本旅游")
        #expect(item.dueDate == nil, "“下周日本旅游”中的“日本”不应被误判为下周日")
        #expect(item.title.contains("日本"))
    }

    // MARK: - 重复规则细节（#4）

    @Test func monthlyDayOfMonth() async throws {
        let item = try await parseSingle("每月15号还信用卡")
        #expect(item.recurrence == .monthly)
        #expect(item.recurrenceDaysOfMonth == [15])
        let dueDate = try #require(item.dueDate, "每月X号应推导出下一次发生日期")
        #expect(Calendar.current.component(.day, from: dueDate) == 15)
    }

    @Test func yearlyMonthAndDay() async throws {
        let item = try await parseSingle("每年3月5日体检")
        #expect(item.recurrence == .yearly)
        #expect(item.recurrenceMonthsOfYear == [3])
        #expect(item.recurrenceDaysOfMonth == [5])
        let components = Calendar.current.dateComponents([.month, .day], from: try #require(item.dueDate))
        #expect(components.month == 3)
        #expect(components.day == 5)
    }

    @Test func monthlyLastFriday() async throws {
        let item = try await parseSingle("每月最后一个周五复盘")
        #expect(item.recurrence == .monthly)
        #expect(item.recurrenceSetPosition == -1)
        #expect(item.recurrenceWeekdays == [5], "周五的 ISO 编号应为 5")
        #expect(item.title.contains("复盘"))
    }

    // MARK: - 英文输入（#9）

    @Test func englishReminderTomorrowAt9am() async throws {
        let item = try await parseSingle("remind me to buy milk tomorrow at 9am")
        #expect(item.type == .reminder)
        #expect(!item.isAllDay)
        let dueDate = try #require(item.dueDate)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        #expect(calendar.isDate(dueDate, inSameDayAs: tomorrow))
        #expect(calendar.component(.hour, from: dueDate) == 9)
        #expect(item.title.lowercased().contains("buy milk"), "标题应保留事项内容，实际：\(item.title)")
    }

    @Test func englishMeetingEveryMonday() async throws {
        let item = try await parseSingle("team meeting every monday at 3pm")
        #expect(item.type == .calendar)
        #expect(item.recurrence == .weekly)
        #expect(item.recurrenceWeekdays == [1], "monday 的 ISO 编号应为 1")
        let dueDate = try #require(item.dueDate)
        #expect(Calendar.current.component(.hour, from: dueDate) == 15)
    }

    @Test func englishRelativeDuration() async throws {
        let item = try await parseSingle("remind me to stretch in 30 minutes")
        let dueDate = try #require(item.dueDate)
        #expect(abs(dueDate.timeIntervalSinceNow - 30 * 60) < 120)
        #expect(item.title.lowercased().contains("stretch"))
    }

    @Test func englishUrgentPriority() async throws {
        let item = try await parseSingle("urgent: fix the broken build")
        #expect(item.priorityValue == 1)
    }

    // MARK: - 既有语法回归

    @Test func chineseCalendarTypeWithTime() async throws {
        let item = try await parseSingle("明天下午3点提醒我开会")
        #expect(item.type == .calendar)
        #expect(!item.isAllDay)
        let dueDate = try #require(item.dueDate)
        let calendar = Calendar.current
        #expect(calendar.component(.hour, from: dueDate) == 15)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        #expect(calendar.isDate(dueDate, inSameDayAs: tomorrow))
    }

    @Test func noReminderKeywordDisablesAlert() async throws {
        let item = try await parseSingle("每天早上8点不提醒我吃药")
        #expect(item.recurrence == .daily)
        #expect(item.alertEnabled == false)
    }

    @Test func alertOffsetMinutes() async throws {
        let item = try await parseSingle("明天9点提前30分钟提醒我吃药")
        #expect(item.alertOffsetMinutes == -30)
    }

    @Test func weeklyMultipleWeekdays() async throws {
        let item = try await parseSingle("每周一周三提醒我健身")
        #expect(item.recurrence == .weekly)
        #expect(item.recurrenceWeekdays == [1, 3])
    }

    @Test func multipleItemsSplitBySemicolon() async throws {
        let items = try await parser.parse("明天9点开会；后天提交报告")
        #expect(items.count == 2)
    }

    @Test func emptyInputThrows() async {
        await #expect(throws: ParserError.self) {
            try await parser.parse("   ")
        }
    }
}
