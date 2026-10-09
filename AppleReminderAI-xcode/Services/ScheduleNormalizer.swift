import Foundation

/// Centralizes date invariants shared by parsers, editors, and EventKit services.
enum ScheduleNormalizer {
    static func normalize(_ source: ParsedItem, calendar: Calendar = .current) -> ParsedItem {
        var item = source

        item.priorityValue = min(max(item.priorityValue, 0), 9)
        item.confidence = min(max(item.confidence, 0), 1)
        item.recurrenceInterval = item.recurrenceInterval.map { max(1, $0) }
        item.recurrenceCount = item.recurrenceCount.map { max(1, $0) }
        item.recurrenceWeekdays = item.recurrenceWeekdays.map {
            Array(Set($0.filter { (1...7).contains($0) })).sorted()
        }
        item.recurrenceDaysOfMonth = item.recurrenceDaysOfMonth.map {
            Array(Set($0.filter { (1...31).contains($0) })).sorted()
        }
        item.recurrenceMonthsOfYear = item.recurrenceMonthsOfYear.map {
            Array(Set($0.filter { (1...12).contains($0) })).sorted()
        }
        item.recurrenceSetPosition = item.recurrenceSetPosition.flatMap {
            ($0 == -1 || (1...4).contains($0)) ? $0 : nil
        }

        item.targetGroupName = trimmedValue(item.targetGroupName)
        item.targetGroupIdentifier = trimmedValue(item.targetGroupIdentifier)

        guard let dueDate = item.dueDate else {
            item.endDate = nil
            item.alertEnabled = false
            item.alertOffsetMinutes = nil
            return item
        }

        if item.isAllDay {
            let start = calendar.startOfDay(for: dueDate)
            item.dueDate = start
            if item.type == .calendar {
                let candidate = item.endDate.map { calendar.startOfDay(for: $0) }
                item.endDate = candidate.map { max($0, start) }
            } else {
                item.endDate = nil
            }
        } else if item.type == .calendar {
            if item.endDate == nil || item.endDate! <= dueDate {
                item.endDate = dueDate.addingTimeInterval(3600)
            }
        } else {
            item.endDate = nil
        }

        if item.alertEnabled == false {
            item.alertOffsetMinutes = nil
        }

        return item
    }

    static func settingAllDay(
        _ enabled: Bool,
        for source: ParsedItem,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedItem {
        var item = source
        item.isAllDay = enabled
        let baseDate = item.dueDate ?? now

        if enabled {
            item.dueDate = calendar.startOfDay(for: baseDate)
            item.alertEnabled = false
            item.alertOffsetMinutes = nil
            if item.type == .calendar {
                item.endDate = item.endDate.map { calendar.startOfDay(for: $0) } ?? item.dueDate
            }
        } else {
            let components = calendar.dateComponents([.hour, .minute], from: baseDate)
            if components.hour == 0 && components.minute == 0 {
                item.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)
            } else {
                item.dueDate = baseDate
            }
            if item.type == .calendar, let dueDate = item.dueDate {
                item.endDate = dueDate.addingTimeInterval(3600)
            }
            item.alertEnabled = true
            item.alertOffsetMinutes = defaultAlertOffset(for: item)
        }

        return normalize(item, calendar: calendar)
    }

    static func defaultAlertOffset(for item: ParsedItem) -> Int {
        item.type == .calendar ? -15 : 0
    }

    static func isAlertEnabled(for item: ParsedItem) -> Bool {
        item.alertEnabled ?? !item.isAllDay
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
