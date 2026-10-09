import Testing
import Foundation
@testable import AppleReminderAICore

/// ScheduleNormalizer 不变量测试
@Suite("日程归一化")
struct ScheduleNormalizerTests {
    private var calendar: Calendar { .current }

    private func makeItem(
        dueDate: Date? = Date(timeIntervalSinceNow: 3600),
        isAllDay: Bool = false,
        type: ItemType = .reminder,
        endDate: Date? = nil
    ) -> ParsedItem {
        ParsedItem(
            type: type,
            title: "测试",
            dueDate: dueDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }

    // MARK: - 新增重复字段校验（#4）

    @Test func recurrenceDetailFieldClamping() {
        var item = makeItem()
        item.recurrence = .monthly
        item.recurrenceDaysOfMonth = [0, 15, 32, 15]
        item.recurrenceMonthsOfYear = [0, 13, 3]
        item.recurrenceSetPosition = 2

        let normalized = ScheduleNormalizer.normalize(item)
        #expect(normalized.recurrenceDaysOfMonth == [15], "非法与重复的月内日期应被过滤")
        #expect(normalized.recurrenceMonthsOfYear == [3], "非法月份应被过滤")
        #expect(normalized.recurrenceSetPosition == 2)
    }

    @Test func invalidSetPositionIsCleared() {
        var item = makeItem()
        item.recurrence = .monthly
        item.recurrenceSetPosition = 5
        #expect(ScheduleNormalizer.normalize(item).recurrenceSetPosition == nil, "5 不在 1-4/-1 范围内应被清除")

        item.recurrenceSetPosition = -1
        #expect(ScheduleNormalizer.normalize(item).recurrenceSetPosition == -1, "-1（最后一个）应保留")
    }

    // MARK: - 既有不变量回归

    @Test func noDueDateClearsEndDateAndAlert() {
        var item = makeItem(dueDate: nil, type: .calendar, endDate: Date())
        item.alertEnabled = true
        item.alertOffsetMinutes = -15

        let normalized = ScheduleNormalizer.normalize(item)
        #expect(normalized.endDate == nil)
        #expect(normalized.alertEnabled == false)
        #expect(normalized.alertOffsetMinutes == nil)
    }

    @Test func allDayReminderStripsTimeAndEndDate() {
        let date = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
        var item = makeItem(dueDate: date, isAllDay: true, type: .reminder, endDate: date)
        item.endDate = date

        let normalized = ScheduleNormalizer.normalize(item)
        #expect(calendar.component(.hour, from: normalized.dueDate!) == 0)
        #expect(normalized.endDate == nil, "全天提醒事项不应有结束时间")
    }

    @Test func calendarEventWithoutEndDateGetsOneHour() {
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let item = makeItem(dueDate: start, type: .calendar, endDate: nil)

        let normalized = ScheduleNormalizer.normalize(item)
        #expect(normalized.endDate?.timeIntervalSince(start) == 3600)
    }

    @Test func settingAllDayOffAssignsNineAmWhenMidnight() {
        let day = calendar.startOfDay(for: Date())
        var item = makeItem(dueDate: day, isAllDay: true)
        item.alertEnabled = false

        let normalized = ScheduleNormalizer.settingAllDay(false, for: item)
        #expect(!normalized.isAllDay)
        #expect(calendar.component(.hour, from: normalized.dueDate!) == 9, "全天切换为定时后午夜应改为 9 点")
        #expect(normalized.alertEnabled == true)
    }

    @Test func priorityAndConfidenceClamped() {
        var item = makeItem()
        item.priorityValue = 42
        item.confidence = 1.7

        let normalized = ScheduleNormalizer.normalize(item)
        #expect(normalized.priorityValue == 9)
        #expect(normalized.confidence == 1.0)
    }
}
