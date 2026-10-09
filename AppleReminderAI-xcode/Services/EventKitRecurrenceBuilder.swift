import EventKit
import Foundation

enum EventKitRecurrenceBuilder {
    static func makeRule(for item: ParsedItem) -> EKRecurrenceRule? {
        guard item.recurrence != .none else { return nil }

        let frequency: EKRecurrenceFrequency
        var interval = max(item.recurrenceInterval ?? 1, 1)
        var weekdays = item.recurrenceWeekdays

        switch item.recurrence {
        case .none:
            return nil
        case .daily:
            frequency = .daily
        case .weekdays:
            frequency = .weekly
            interval = 1
            weekdays = [1, 2, 3, 4, 5]
        case .weekly:
            frequency = .weekly
        case .biweekly:
            frequency = .weekly
            interval = 2
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        }

        let recurrenceEnd: EKRecurrenceEnd?
        if let count = item.recurrenceCount, count > 0 {
            recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
        } else if let endDate = item.recurrenceEndDate {
            recurrenceEnd = EKRecurrenceEnd(end: endDate)
        } else {
            recurrenceEnd = nil
        }

        // "每月15号" / "每年3月5日" 需要月内日期；年份细节还需要月份
        let supportsMonthDayDetails = item.recurrence == .monthly || item.recurrence == .yearly
        let daysOfMonth: [NSNumber]? = supportsMonthDayDetails
            ? item.recurrenceDaysOfMonth?.compactMap { (1...31).contains($0) ? NSNumber(value: $0) : nil }
            : nil
        let monthsOfYear: [NSNumber]? = item.recurrence == .yearly
            ? item.recurrenceMonthsOfYear?.compactMap { (1...12).contains($0) ? NSNumber(value: $0) : nil }
            : nil

        // "每月最后一个周五" 需要月内第 N 个星期几（setPositions 配合 daysOfTheWeek 使用）
        var setPositions: [NSNumber]?
        if item.recurrence == .monthly,
           let position = item.recurrenceSetPosition,
           position == -1 || (1...4).contains(position),
           let weekdayList = weekdays, !weekdayList.isEmpty {
            setPositions = [NSNumber(value: position)]
        }

        let daysOfWeek = weekdays?.compactMap(dayOfWeek)
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek?.isEmpty == false ? daysOfWeek : nil,
            daysOfTheMonth: daysOfMonth?.isEmpty == false ? daysOfMonth : nil,
            monthsOfTheYear: monthsOfYear?.isEmpty == false ? monthsOfYear : nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: setPositions,
            end: recurrenceEnd
        )
    }

    private static func dayOfWeek(_ isoWeekday: Int) -> EKRecurrenceDayOfWeek? {
        let weekday: EKWeekday
        switch isoWeekday {
        case 1: weekday = .monday
        case 2: weekday = .tuesday
        case 3: weekday = .wednesday
        case 4: weekday = .thursday
        case 5: weekday = .friday
        case 6: weekday = .saturday
        case 7: weekday = .sunday
        default: return nil
        }
        return EKRecurrenceDayOfWeek(weekday)
    }
}
