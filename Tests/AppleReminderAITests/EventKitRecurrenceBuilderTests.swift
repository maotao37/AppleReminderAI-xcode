import Testing
import Foundation
import EventKit
@testable import AppleReminderAICore

/// EventKitRecurrenceBuilder 重复规则构建测试
@Suite("重复规则构建")
struct EventKitRecurrenceBuilderTests {
    private func makeItem(_ configure: (inout ParsedItem) -> Void) -> ParsedItem {
        var item = ParsedItem(
            title: "测试",
            dueDate: Date(timeIntervalSinceNow: 3600)
        )
        configure(&item)
        return item
    }

    @Test func monthlyDayOfMonth() throws {
        let item = makeItem { item in
            item.recurrence = .monthly
            item.recurrenceDaysOfMonth = [15]
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.frequency == .monthly)
        #expect(rule.daysOfTheMonth?.map(\.intValue) == [15])
        #expect(rule.setPositions == nil)
    }

    @Test func yearlyMonthAndDay() throws {
        let item = makeItem { item in
            item.recurrence = .yearly
            item.recurrenceMonthsOfYear = [3]
            item.recurrenceDaysOfMonth = [5]
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.frequency == .yearly)
        #expect(rule.monthsOfTheYear?.map(\.intValue) == [3])
        #expect(rule.daysOfTheMonth?.map(\.intValue) == [5])
    }

    @Test func monthlyLastFriday() throws {
        let item = makeItem { item in
            item.recurrence = .monthly
            item.recurrenceWeekdays = [5]
            item.recurrenceSetPosition = -1
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.frequency == .monthly)
        #expect(rule.setPositions?.map(\.intValue) == [-1])
        #expect(rule.daysOfTheWeek?.count == 1)
        #expect(rule.daysOfTheWeek?.first?.dayOfTheWeek == .friday)
    }

    @Test func monthlyDayOfMonthIgnoresSetPositionWithoutWeekday() throws {
        let item = makeItem { item in
            item.recurrence = .monthly
            item.recurrenceDaysOfMonth = [15]
            item.recurrenceSetPosition = -1
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.setPositions == nil, "没有星期几时 setPositions 不应生效")
    }

    @Test func weekdaysRuleUsesMondayToFriday() throws {
        let item = makeItem { $0.recurrence = .weekdays }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.frequency == .weekly)
        #expect(rule.daysOfTheWeek?.count == 5)
        #expect(rule.interval == 1)
    }

    @Test func biweeklyUsesIntervalTwo() throws {
        let item = makeItem { $0.recurrence = .biweekly }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.frequency == .weekly)
        #expect(rule.interval == 2)
    }

    @Test func recurrenceCountEnd() throws {
        let item = makeItem { item in
            item.recurrence = .daily
            item.recurrenceCount = 10
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.recurrenceEnd?.occurrenceCount == 10)
    }

    @Test func noneReturnsNil() {
        let item = makeItem { $0.recurrence = .none }
        #expect(EventKitRecurrenceBuilder.makeRule(for: item) == nil)
    }

    @Test func dailyIgnoresMonthlyDetails() throws {
        let item = makeItem { item in
            item.recurrence = .daily
            item.recurrenceDaysOfMonth = [15]
        }
        let rule = try #require(EventKitRecurrenceBuilder.makeRule(for: item))
        #expect(rule.daysOfTheMonth == nil, "daily 不应携带月内日期")
    }
}
