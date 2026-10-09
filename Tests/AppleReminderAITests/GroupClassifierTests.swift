import Testing
import Foundation
import EventKit
@testable import AppleReminderAICore

/// GroupClassifier 分组匹配测试
@Suite("自动分组")
struct GroupClassifierTests {
    private let store = EKEventStore()

    private func makeList(_ title: String) -> EKCalendar {
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = title
        return calendar
    }

    @Test func exactPreferredNameWins() {
        let work = makeList("工作")
        let home = makeList("家庭")
        var item = ParsedItem(title: "交周报", originalText: "交周报")
        item.targetGroupName = "工作"

        let result = GroupClassifier.assign(
            item,
            reminderLists: [home, work],
            calendars: [],
            defaultReminderList: home,
            defaultCalendar: nil
        )
        #expect(result.targetGroupIdentifier == work.calendarIdentifier)
        #expect(result.targetGroupName == "工作")
    }

    @Test func semanticCategoryMatchBeatsFallback() {
        let work = makeList("工作")
        let home = makeList("家庭")
        let item = ParsedItem(title: "提交项目周报", originalText: "提交项目周报")

        let result = GroupClassifier.assign(
            item,
            reminderLists: [home, work],
            calendars: [],
            defaultReminderList: home,
            defaultCalendar: nil
        )
        #expect(result.targetGroupName == "工作", "工作语义内容应匹配“工作”列表而非默认列表")
    }

    @Test func noSignalFallsBackToDefault() {
        let home = makeList("家庭")
        let work = makeList("工作")
        let item = ParsedItem(title: "随便记录一下", originalText: "随便记录一下")

        let result = GroupClassifier.assign(
            item,
            reminderLists: [work, home],
            calendars: [],
            defaultReminderList: home,
            defaultCalendar: nil
        )
        #expect(result.targetGroupName == "家庭", "无匹配信号时应回退默认列表")
    }

    @Test func emptyCandidatesClearsAssignment() {
        var item = ParsedItem(title: "测试", originalText: "测试")
        item.targetGroupName = "工作"

        let result = GroupClassifier.assign(
            item,
            reminderLists: [],
            calendars: [],
            defaultReminderList: nil,
            defaultCalendar: nil
        )
        #expect(result.targetGroupIdentifier == nil)
        #expect(result.targetGroupName == nil)
    }

    @Test func calendarTypeUsesCalendarCandidates() {
        let reminderList = makeList("工作")
        let eventCalendar = makeList("日程")
        let item = ParsedItem(type: .calendar, title: "周会", originalText: "周会")

        let result = GroupClassifier.assign(
            item,
            reminderLists: [reminderList],
            calendars: [eventCalendar],
            defaultReminderList: reminderList,
            defaultCalendar: eventCalendar
        )
        #expect(result.targetGroupIdentifier == eventCalendar.calendarIdentifier, "日历类型应只在日历候选中匹配")
    }
}
