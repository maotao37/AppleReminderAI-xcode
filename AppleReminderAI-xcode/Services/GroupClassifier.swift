import EventKit
import Foundation

/// Resolves a parsed semantic group name to one of the user's existing EventKit groups.
enum GroupClassifier {
    static func assign(
        _ source: ParsedItem,
        reminderLists: [EKCalendar],
        calendars: [EKCalendar],
        defaultReminderList: EKCalendar?,
        defaultCalendar: EKCalendar?
    ) -> ParsedItem {
        var item = source
        let candidates = item.type == .reminder ? reminderLists : calendars
        let fallback = item.type == .reminder ? defaultReminderList : defaultCalendar

        guard !candidates.isEmpty else {
            item.targetGroupIdentifier = nil
            item.targetGroupName = nil
            return item
        }

        let context = normalized([item.title, item.notes, item.originalText].compactMap { $0 }.joined(separator: " "))
        let preferredName = normalized(item.targetGroupName ?? "")

        let best = candidates
            .map { candidate in
                (candidate: candidate, score: score(candidate.title, preferredName: preferredName, context: context))
            }
            .max { $0.score < $1.score }

        let selected = (best?.score ?? 0) >= 35 ? best?.candidate : fallback ?? candidates.first
        item.targetGroupIdentifier = selected?.calendarIdentifier
        item.targetGroupName = selected?.title
        return item
    }

    private static func score(_ title: String, preferredName: String, context: String) -> Int {
        let normalizedTitle = normalized(title)
        var value = 0

        if !preferredName.isEmpty {
            if normalizedTitle == preferredName {
                value += 120
            } else if normalizedTitle.contains(preferredName) || preferredName.contains(normalizedTitle) {
                value += 80
            }
        }

        if normalizedTitle.count >= 2, context.contains(normalizedTitle) {
            value += 70
        }

        for category in categories {
            let contentMatches = category.contentKeywords.filter { context.contains(normalized($0)) }.count
            let groupMatches = category.groupKeywords.filter { normalizedTitle.contains(normalized($0)) }.count
            if contentMatches > 0, groupMatches > 0 {
                value += 30 + min(contentMatches * 8, 32) + min(groupMatches * 5, 15)
            }
        }

        return value
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[\s\p{P}\p{S}]+"#, with: "", options: .regularExpression)
            .lowercased()
    }

    private static let categories: [(contentKeywords: [String], groupKeywords: [String])] = [
        (["工作", "公司", "项目", "客户", "会议", "周报", "汇报", "面试", "同事"], ["工作", "办公", "公司", "项目", "work", "business", "office"]),
        (["家", "家庭", "孩子", "父母", "家人", "家务"], ["家庭", "家人", "家务", "home", "family"]),
        (["买", "采购", "超市", "购物", "下单", "快递"], ["购物", "采购", "清单", "shopping", "grocery"]),
        (["学习", "课程", "考试", "作业", "阅读", "复习", "论文"], ["学习", "学校", "课程", "study", "school"]),
        (["运动", "健身", "跑步", "体检", "吃药", "医院", "睡眠"], ["健康", "健身", "运动", "health", "fitness"]),
        (["付款", "缴费", "账单", "报销", "还款", "工资", "税"], ["财务", "账单", "付款", "finance", "bill"]),
        (["旅行", "出差", "航班", "酒店", "火车", "签证", "行程"], ["旅行", "出差", "行程", "travel", "trip"]),
        (["生日", "纪念日", "节日"], ["生日", "纪念日", "birthday", "anniversary"])
    ]
}
