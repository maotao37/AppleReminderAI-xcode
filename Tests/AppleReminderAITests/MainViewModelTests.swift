import Testing
import Foundation
@testable import AppleReminderAICore

/// MainViewModel 类型切换与解析结果编辑测试
@Suite("主视图模型")
struct MainViewModelTests {

    @Test func setItemTypeSwitchesTypeAndNormalizes() {
        let viewModel = MainViewModel()
        var item = ParsedItem(title: "测试事项", originalText: "测试事项")
        item.type = .reminder
        item.dueDate = Date(timeIntervalSinceNow: 3600)
        viewModel.parsedItems = [item]

        viewModel.setItemType(.calendar, at: 0)

        #expect(viewModel.parsedItems[0].type == .calendar, "类型应切换为日历事件")
        #expect(viewModel.parsedItems[0].endDate != nil, "切成日历事件应补默认 1 小时结束时间")
        #expect(viewModel.parsedItems.count == 1)
    }

    @Test func setItemTypeCalendarToReminderClearsEndDate() {
        let viewModel = MainViewModel()
        var item = ParsedItem(title: "会议", originalText: "会议")
        item.type = .calendar
        item.dueDate = Date(timeIntervalSinceNow: 3600)
        item.endDate = Date(timeIntervalSinceNow: 7200)
        viewModel.parsedItems = [item]

        viewModel.setItemType(.reminder, at: 0)

        #expect(viewModel.parsedItems[0].type == .reminder)
        #expect(viewModel.parsedItems[0].endDate == nil, "提醒事项不应保留结束时间")
    }

    @Test func setItemTypeInvalidIndexIsNoop() {
        let viewModel = MainViewModel()
        let item = ParsedItem(title: "测试", originalText: "测试")
        viewModel.parsedItems = [item]

        viewModel.setItemType(.calendar, at: 5)
        viewModel.setItemType(.calendar, at: -1)

        #expect(viewModel.parsedItems.count == 1)
        #expect(viewModel.parsedItems[0].type == .reminder, "非法索引不应产生任何影响")
    }

    @Test func setSameTypeKeepsItemStable() {
        let viewModel = MainViewModel()
        var item = ParsedItem(title: "测试", originalText: "测试")
        item.type = .reminder
        item.recurrence = .daily
        viewModel.parsedItems = [item]

        viewModel.setItemType(.reminder, at: 0)

        #expect(viewModel.parsedItems[0].type == .reminder)
        #expect(viewModel.parsedItems[0].recurrence == .daily, "重复规则不应因类型设置而丢失")
    }
}
