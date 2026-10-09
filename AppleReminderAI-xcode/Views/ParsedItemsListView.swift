//
//  ParsedItemsListView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  解析结果列表视图
//  显示多个解析出的事项，支持展开编辑和批量操作
//

import SwiftUI
import EventKit

/// 解析结果列表视图
/// 显示所有解析出的事项卡片，支持逐个或批量创建
struct ParsedItemsListView: View {
    /// 解析出的事项数组
    @Binding var items: [ParsedItem]
    
    /// 创建单个事项回调
    var onCreateItem: (Int) -> Void
    
    /// 创建所有事项回调
    var onCreateAll: () -> Void
    
    /// 删除事项回调
    var onRemoveItem: (Int) -> Void
    
    /// 更新事项回调
    var onUpdateItem: (ParsedItem, Int) -> Void

    /// 设置事项类型回调（提醒事项/日历事件切换）
    var onSetItemType: (ItemType, Int) -> Void
    
    /// 是否正在创建
    var isCreating: Bool

    /// 批量创建进度（第 N 个 / 共 M 个）
    var creationProgress: (current: Int, total: Int)? = nil
    
    /// 可用的提醒事项列表
    var reminderLists: [EKCalendar]
    
    /// 可用的日历列表
    var calendars: [EKCalendar]
    
    /// 选中的提醒事项列表
    @Binding var selectedReminderList: EKCalendar?
    
    /// 选中的日历
    @Binding var selectedCalendar: EKCalendar?
    
    /// 当前展开编辑的事项索引
    @State private var expandedIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部标题和批量操作
            HStack {
                Label(L10n.Main.parseResultCount(items.count), systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 全部创建按钮
                if items.count > 1 {
                    Button {
                        onCreateAll()
                    } label: {
                        HStack(spacing: 4) {
                            if isCreating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                if let progress = creationProgress {
                                    Text(L10n.ParsedList.creatingProgress(progress.current, progress.total))
                                } else {
                                    Text(L10n.ParsedList.createAll)
                                }
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(L10n.ParsedList.createAll)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreating)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                }
            }
            .padding(.horizontal)
            
            // 事项列表
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ParsedItemCardView(
                            item: Binding(
                                get: { items[index] },
                                set: { onUpdateItem($0, index) }
                            ),
                            index: index,
                            isExpanded: expandedIndex == index,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedIndex = expandedIndex == index ? nil : index
                                }
                            },
                            onConfirm: { onCreateItem(index) },
                            onRemove: { onRemoveItem(index) },
                            onSetType: { newType in onSetItemType(newType, index) },
                            isCreating: isCreating,
                            reminderLists: reminderLists,
                            calendars: calendars,
                            selectedReminderList: $selectedReminderList,
                            selectedCalendar: $selectedCalendar
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
}

/// 单个解析事项卡片视图
struct ParsedItemCardView: View {
    @Binding var item: ParsedItem
    var index: Int
    var isExpanded: Bool
    var onToggleExpand: () -> Void
    var onConfirm: () -> Void
    var onRemove: () -> Void
    /// 类型切换回调：由外部（ViewModel）单次原子处理，避免内联多重写回
    var onSetType: (ItemType) -> Void
    var isCreating: Bool
    
    var reminderLists: [EKCalendar]
    var calendars: [EKCalendar]
    @Binding var selectedReminderList: EKCalendar?
    @Binding var selectedCalendar: EKCalendar?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部：摘要信息
            HStack {
                // 类型图标
                Image(systemName: item.type.icon)
                    .foregroundColor(item.type == .calendar ? .orange : .blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    // 标题
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // 时间信息
                    HStack(spacing: 8) {
                        if item.dueDate != nil {
                            Text(item.type == .calendar ? item.formattedDateRange : item.formattedDueDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if item.recurrence != .none {
                            Label(item.recurrenceSummary, systemImage: item.recurrence.icon)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }

                        if let groupName = item.targetGroupName {
                            Label(groupName, systemImage: "folder.fill")
                                .font(.caption2)
                                .foregroundColor(.teal)
                        }

                        if item.confidence < 0.7 {
                            Label(L10n.ParsedList.lowConfidence, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮组
                HStack(spacing: 8) {
                    // 删除按钮
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.Common.remove)
                    
                    // 展开/收起按钮
                    Button {
                        onToggleExpand()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isExpanded ? L10n.Common.collapseEdit : L10n.Common.expandEdit)
                    
                    // 快速创建按钮
                    Button {
                        onConfirm()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreating)
                    .help(L10n.Common.createThisItem)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }
            
            // 展开的编辑区域
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    // 类型切换
                    HStack {
                        Text(L10n.ParsedList.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { item.type },
                            set: { newType in onSetType(newType) }
                        )) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 160)
                    }
                    
                    // 标题编辑
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.ParsedList.titleField)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(L10n.ParsedList.titlePlaceholder, text: $item.title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // 时间选择
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 16)], alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type == .calendar ? L10n.ParsedList.startTime : L10n.ParsedList.reminderTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: Binding(
                                get: { item.dueDate ?? Date() },
                                set: {
                                    item.dueDate = $0
                                    item = ScheduleNormalizer.normalize(item)
                                }
                            ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.stepperField)
                        }
                        
                        if item.type == .calendar {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.ParsedList.endTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: Binding(
                                    get: { item.endDate ?? (item.dueDate?.addingTimeInterval(3600) ?? Date()) },
                                    set: {
                                        item.endDate = $0
                                        item = ScheduleNormalizer.normalize(item)
                                    }
                                ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                            }
                        }
                        
                        // 全天切换
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.ParsedList.allDay)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Toggle("", isOn: Binding(
                                get: { item.isAllDay },
                                set: { item = ScheduleNormalizer.settingAllDay($0, for: item) }
                            ))
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                    }
                    
                    // 重复、提醒和优先级
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 16)], alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.ParsedList.recurrence)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $item.recurrence) {
                                ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                                    Text(rule.rawValue).tag(rule)
                                }
                            }
                            .frame(width: 100)
                        }

                        if item.recurrence != .none && item.recurrence != .weekdays && item.recurrence != .biweekly {
                            Stepper(
                                L10n.ParsedList.interval(item.recurrenceInterval ?? 1),
                                value: Binding(
                                    get: { item.recurrenceInterval ?? 1 },
                                    set: { item.recurrenceInterval = $0 }
                                ),
                                in: 1...30
                            )
                            .font(.caption)
                            .frame(width: 100)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.ParsedList.alert)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Toggle("", isOn: Binding(
                                get: { ScheduleNormalizer.isAlertEnabled(for: item) },
                                set: {
                                    item.alertEnabled = $0
                                    if $0 && item.alertOffsetMinutes == nil {
                                        item.alertOffsetMinutes = ScheduleNormalizer.defaultAlertOffset(for: item)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }

                        if ScheduleNormalizer.isAlertEnabled(for: item), item.dueDate != nil {
                            Picker("", selection: Binding(
                                get: { item.alertOffsetMinutes ?? ScheduleNormalizer.defaultAlertOffset(for: item) },
                                set: { item.alertOffsetMinutes = $0 }
                            )) {
                                Text(L10n.ParsedList.alertOnTime).tag(0)
                                Text(L10n.ParsedList.minutesEarly(5)).tag(-5)
                                Text(L10n.ParsedList.minutesEarly(15)).tag(-15)
                                Text(L10n.ParsedList.minutesEarly(30)).tag(-30)
                                Text(L10n.ParsedList.alertEarly1Hour).tag(-60)
                                Text(L10n.ParsedList.alertEarly1Day).tag(-1440)
                            }
                            .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.ParsedList.priority)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: Binding(
                                get: { item.priority },
                                set: { item.priority = $0 }
                            )) {
                                ForEach(Priority.allCases, id: \.self) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .frame(width: 80)
                        }
                    }

                    if item.recurrence == .weekly {
                        WeekdaySelectionView(selection: Binding(
                            get: { item.recurrenceWeekdays ?? [] },
                            set: { item.recurrenceWeekdays = $0 }
                        ))
                    }

                    // "每月15号" / "每月最后一个周五" 细节编辑
                    if item.recurrence == .monthly {
                        MonthlyRecurrenceEditor(item: $item)
                    }

                    // "每年3月5日" 细节编辑
                    if item.recurrence == .yearly {
                        YearlyRecurrenceEditor(item: $item)
                    }

                    if item.recurrence != .none {
                        Toggle(L10n.ParsedList.recurrenceEndToggle, isOn: Binding(
                            get: { item.recurrenceEndDate != nil },
                            set: { item.recurrenceEndDate = $0 ? (item.dueDate ?? Date()) : nil }
                        ))
                        .font(.caption)

                        if let recurrenceEndDate = item.recurrenceEndDate {
                            DatePicker(L10n.ParsedList.recurrenceEnd, selection: Binding(
                                get: { recurrenceEndDate },
                                set: { item.recurrenceEndDate = $0 }
                            ), displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                        }
                    }
                    
                    // 目标列表选择
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.type == .reminder ? L10n.ParsedList.saveToReminderList : L10n.ParsedList.saveToCalendar)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if availableGroups.isEmpty {
                            Label(L10n.ParsedList.permissionPendingGroup, systemImage: "lock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("", selection: targetGroupBinding) {
                                ForEach(availableGroups, id: \.calendarIdentifier) { group in
                                    Text(group.title).tag(Optional(group.calendarIdentifier))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.ParsedList.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(L10n.Common.optional, text: Binding(
                            get: { item.notes ?? "" },
                            set: { item.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    if item.type == .calendar && item.dueDate == nil {
                        Label(L10n.ParsedList.calendarNeedsDate, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // 确认创建按钮
                    Button {
                        onConfirm()
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView().controlSize(.small).padding(.trailing, 4)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(L10n.ParsedList.confirmCreate(typeName: item.type.rawValue))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreating || item.title.isEmpty || (item.type == .calendar && item.dueDate == nil))
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var availableGroups: [EKCalendar] {
        item.type == .reminder ? reminderLists : calendars
    }

    private var targetGroupBinding: Binding<String?> {
        Binding(
            get: {
                item.targetGroupIdentifier
                    ?? (item.type == .reminder
                        ? selectedReminderList?.calendarIdentifier
                        : selectedCalendar?.calendarIdentifier)
            },
            set: { identifier in
                item.targetGroupIdentifier = identifier
                item.targetGroupName = availableGroups.first(where: { $0.calendarIdentifier == identifier })?.title
            }
        )
    }
}

private struct WeekdaySelectionView: View {
    @Binding var selection: [Int]
    private let labels = L10n.RecurrenceDisplay.weekdayShort

    var body: some View {
        HStack(spacing: 6) {
            Text(L10n.ParsedList.repeatOn)
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(1...7, id: \.self) { day in
                Button {
                    if selection.contains(day) {
                        selection.removeAll { $0 == day }
                    } else {
                        selection.append(day)
                        selection.sort()
                    }
                } label: {
                    Text(labels[day - 1])
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(selection.contains(day) ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundColor(selection.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 每月重复的细节编辑：按日期（每月15号）或按第 N 个星期几（每月最后一个周五）
private struct MonthlyRecurrenceEditor: View {
    @Binding var item: ParsedItem
    private let weekdayLabels = L10n.RecurrenceDisplay.weekdays

    /// 0=仅每月，1=按月内日期，2=按第 N 个星期几
    private var mode: Int {
        if item.recurrenceSetPosition != nil,
           let weekdays = item.recurrenceWeekdays, !weekdays.isEmpty {
            return 2
        }
        if let days = item.recurrenceDaysOfMonth, !days.isEmpty {
            return 1
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.ParsedList.monthlyRule)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: Binding(get: { mode }, set: { switchMode($0) })) {
                Text(L10n.ParsedList.monthlyPlain).tag(0)
                Text(L10n.ParsedList.monthlyByDate).tag(1)
                Text(L10n.ParsedList.monthlyByNthWeekday).tag(2)
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 130)

            switch mode {
            case 1:
                Stepper(
                    L10n.ParsedList.monthlyByDateNth(item.recurrenceDaysOfMonth?.first ?? 15),
                    value: Binding(
                        get: { item.recurrenceDaysOfMonth?.first ?? 15 },
                        set: { item.recurrenceDaysOfMonth = [$0] }
                    ),
                    in: 1...31
                )
                .font(.caption)

            case 2:
                Picker("", selection: Binding(
                    get: { item.recurrenceSetPosition ?? -1 },
                    set: { item.recurrenceSetPosition = $0 }
                )) {
                    Text(L10n.ParsedList.nthFirst).tag(1)
                    Text(L10n.ParsedList.nthSecond).tag(2)
                    Text(L10n.ParsedList.nthThird).tag(3)
                    Text(L10n.ParsedList.nthFourth).tag(4)
                    Text(L10n.ParsedList.nthLast).tag(-1)
                }
                .frame(width: 90)

                Picker("", selection: Binding(
                    get: { item.recurrenceWeekdays?.first ?? 5 },
                    set: { item.recurrenceWeekdays = [$0] }
                )) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdayLabels[weekday - 1]).tag(weekday)
                    }
                }
                .frame(width: 90)

            default:
                EmptyView()
            }
        }
        .font(.caption)
    }

    private func switchMode(_ newMode: Int) {
        switch newMode {
        case 1:
            item.recurrenceDaysOfMonth = [item.recurrenceDaysOfMonth?.first ?? 15]
            item.recurrenceSetPosition = nil
            item.recurrenceWeekdays = nil
        case 2:
            item.recurrenceSetPosition = item.recurrenceSetPosition ?? -1
            item.recurrenceWeekdays = [item.recurrenceWeekdays?.first ?? 5]
            item.recurrenceDaysOfMonth = nil
        default:
            item.recurrenceDaysOfMonth = nil
            item.recurrenceSetPosition = nil
            item.recurrenceWeekdays = nil
        }
    }
}

/// 每年重复的细节编辑：每年几月几日
private struct YearlyRecurrenceEditor: View {
    @Binding var item: ParsedItem

    var body: some View {
        HStack(spacing: 16) {
            Text(L10n.ParsedList.yearlyOn)
                .font(.caption)
                .foregroundColor(.secondary)
            Stepper(
                L10n.ParsedList.monthNumber(item.recurrenceMonthsOfYear?.first ?? 3),
                value: Binding(
                    get: { item.recurrenceMonthsOfYear?.first ?? 3 },
                    set: { item.recurrenceMonthsOfYear = [$0] }
                ),
                in: 1...12
            )
            Stepper(
                L10n.ParsedList.dayNumber(item.recurrenceDaysOfMonth?.first ?? 5),
                value: Binding(
                    get: { item.recurrenceDaysOfMonth?.first ?? 5 },
                    set: { item.recurrenceDaysOfMonth = [$0] }
                ),
                in: 1...31
            )
        }
        .font(.caption)
    }
}
