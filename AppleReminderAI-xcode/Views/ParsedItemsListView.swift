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
        VStack(spacing: 12) {
            // 顶部标题和批量操作工具栏
            HStack(alignment: .center) {
                // 结果数量提示标签
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                    Text(L10n.Main.parseResultCount(items.count))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.04))
                )
                
                Spacer()
                
                // 全部创建操作按钮
                if items.count > 1 {
                    Button {
                        onCreateAll()
                    } label: {
                        HStack(spacing: 5) {
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
                                    .font(.system(size: 11, weight: .semibold))
                                Text(L10n.ParsedList.createAll)
                                
                                // 快捷键提示
                                Text("⇧⌘↩")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                    }
                    .buttonStyle(MacOS27PrimaryButtonStyle(gradient: MacOS27Theme.successGradient))
                    .disabled(isCreating)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                }
            }
            .padding(.horizontal, 16)
            
            // 事项卡片滚动列表
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ParsedItemCardView(
                            item: Binding(
                                get: { items[index] },
                                set: { onUpdateItem($0, index) }
                            ),
                            index: index,
                            isExpanded: expandedIndex == index,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
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
                .padding(.horizontal, 16)
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
    var onSetType: (ItemType) -> Void
    var isCreating: Bool
    
    var reminderLists: [EKCalendar]
    var calendars: [EKCalendar]
    @Binding var selectedReminderList: EKCalendar?
    @Binding var selectedCalendar: EKCalendar?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部：摘要展示与快捷操作
            HStack(spacing: 12) {
                // 类型立体微图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.type == .calendar ? MacOS27Theme.calendarGradient : MacOS27Theme.reminderGradient)
                        .frame(width: 32, height: 32)
                        .shadow(
                            color: (item.type == .calendar ? Color.orange : Color.blue).opacity(0.25),
                            radius: 3,
                            x: 0,
                            y: 1.5
                        )
                    
                    Image(systemName: item.type.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                // 核心标题与状态标签
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    
                    // 属性徽标集群
                    HStack(spacing: 6) {
                        if item.dueDate != nil {
                            MacOS27Badge(
                                text: item.type == .calendar ? item.formattedDateRange : item.formattedDueDate,
                                icon: "clock",
                                foregroundColor: .secondary,
                                backgroundColor: Color.primary.opacity(0.05)
                            )
                        }
                        
                        if item.recurrence != .none {
                            MacOS27Badge(
                                text: item.recurrenceSummary,
                                icon: item.recurrence.icon,
                                foregroundColor: Color(red: 0.65, green: 0.35, blue: 0.95),
                                backgroundColor: Color.purple.opacity(0.08)
                            )
                        }

                        if let groupName = item.targetGroupName {
                            MacOS27Badge(
                                text: groupName,
                                icon: "folder.fill",
                                foregroundColor: Color(red: 0.10, green: 0.65, blue: 0.70),
                                backgroundColor: Color.teal.opacity(0.08)
                            )
                        }

                        if item.confidence < 0.7 {
                            MacOS27Badge(
                                text: L10n.ParsedList.lowConfidence,
                                icon: "exclamationmark.triangle.fill",
                                foregroundColor: Color.orange,
                                backgroundColor: Color.orange.opacity(0.08)
                            )
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮组
                HStack(spacing: 6) {
                    // 删除按钮
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(MacOS27CircleIconButtonStyle(
                        tintColor: .secondary,
                        activeTintColor: Color(red: 0.95, green: 0.30, blue: 0.35),
                        diameter: 26
                    ))
                    .help(L10n.Common.remove)
                    
                    // 展开/收起详情按钮
                    Button {
                        onToggleExpand()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(MacOS27CircleIconButtonStyle(diameter: 26))
                    .help(isExpanded ? L10n.Common.collapseEdit : L10n.Common.expandEdit)
                    
                    // 快速创建确认按钮
                    Button {
                        onConfirm()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .buttonStyle(MacOS27CircleIconButtonStyle(
                        tintColor: Color(red: 0.15, green: 0.75, blue: 0.45),
                        activeTintColor: .white,
                        diameter: 26
                    ))
                    .disabled(isCreating)
                    .help(L10n.Common.createThisItem)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }
            
            // 展开状态的详细编辑面板
            if isExpanded {
                Divider()
                    .opacity(0.5)
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 14) {
                    // 类型分段控制器
                    HStack(spacing: 12) {
                        Text(L10n.ParsedList.type)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        Picker("", selection: Binding(
                            get: { item.type },
                            set: { newType in onSetType(newType) }
                        )) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 170)
                    }
                    
                    // 标题编辑行
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.ParsedList.titleField)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField(L10n.ParsedList.titlePlaceholder, text: $item.title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12.5, weight: .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(NSColor.textBackgroundColor).opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.6)
                            )
                    }
                    
                    // 时间配置面板模块
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], alignment: .leading, spacing: 10) {
                            // 开始/提醒时间
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.type == .calendar ? L10n.ParsedList.startTime : L10n.ParsedList.reminderTime)
                                    .font(.system(size: 11, weight: .medium))
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
                            
                            // 结束时间（日历专属）
                            if item.type == .calendar {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.ParsedList.endTime)
                                        .font(.system(size: 11, weight: .medium))
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
                            
                            // 全天开关
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.ParsedList.allDay)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Toggle("", isOn: Binding(
                                    get: { item.isAllDay },
                                    set: { item = ScheduleNormalizer.settingAllDay($0, for: item) }
                                ))
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.025))
                    )
                    
                    // 重复周期与优先级配置
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], alignment: .leading, spacing: 10) {
                            // 循环规则
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.ParsedList.recurrence)
                                    .font(.system(size: 11, weight: .medium))
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
                                .font(.system(size: 11))
                                .frame(width: 100)
                            }

                            // 预警通知开关
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.ParsedList.alert)
                                    .font(.system(size: 11, weight: .medium))
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

                            // 预警提前量
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
                                .frame(width: 110)
                            }
                            
                            // 优先级
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.ParsedList.priority)
                                    .font(.system(size: 11, weight: .medium))
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

                        // 按星期重复
                        if item.recurrence == .weekly {
                            WeekdaySelectionView(selection: Binding(
                                get: { item.recurrenceWeekdays ?? [] },
                                set: { item.recurrenceWeekdays = $0 }
                            ))
                            .padding(.top, 2)
                        }

                        // 每月重复细节
                        if item.recurrence == .monthly {
                            MonthlyRecurrenceEditor(item: $item)
                                .padding(.top, 2)
                        }

                        // 每年重复细节
                        if item.recurrence == .yearly {
                            YearlyRecurrenceEditor(item: $item)
                                .padding(.top, 2)
                        }

                        // 重复截止日期
                        if item.recurrence != .none {
                            HStack {
                                Toggle(L10n.ParsedList.recurrenceEndToggle, isOn: Binding(
                                    get: { item.recurrenceEndDate != nil },
                                    set: { item.recurrenceEndDate = $0 ? (item.dueDate ?? Date()) : nil }
                                ))
                                .font(.system(size: 11))

                                if let recurrenceEndDate = item.recurrenceEndDate {
                                    DatePicker(L10n.ParsedList.recurrenceEnd, selection: Binding(
                                        get: { recurrenceEndDate },
                                        set: { item.recurrenceEndDate = $0 }
                                    ), displayedComponents: .date)
                                    .datePickerStyle(.stepperField)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.025))
                    )
                    
                    // 存储目标列表选择
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.type == .reminder ? L10n.ParsedList.saveToReminderList : L10n.ParsedList.saveToCalendar)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if availableGroups.isEmpty {
                            Label(L10n.ParsedList.permissionPendingGroup, systemImage: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Picker("", selection: targetGroupBinding) {
                                ForEach(availableGroups, id: \.calendarIdentifier) { group in
                                    Text(group.title).tag(Optional(group.calendarIdentifier))
                                }
                            }
                        }
                    }

                    // 备注输入框
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.ParsedList.notes)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField(L10n.Common.optional, text: Binding(
                            get: { item.notes ?? "" },
                            set: { item.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
                        )
                    }

                    if item.type == .calendar && item.dueDate == nil {
                        Label(L10n.ParsedList.calendarNeedsDate, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    
                    // 确认创建主操作按钮
                    Button {
                        onConfirm()
                    } label: {
                        HStack(spacing: 6) {
                            if isCreating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(L10n.ParsedList.confirmCreate(typeName: item.type.rawValue))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    .buttonStyle(MacOS27PrimaryButtonStyle(
                        gradient: item.type == .calendar ? MacOS27Theme.calendarGradient : MacOS27Theme.primaryGradient,
                        isFullWidth: true
                    ))
                    .disabled(isCreating || item.title.isEmpty || (item.type == .calendar && item.dueDate == nil))
                }
                .padding(14)
            }
        }
        .macOS27Card(cornerRadius: 12, isSelected: isExpanded)
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

/// 星期多选器组件
private struct WeekdaySelectionView: View {
    @Binding var selection: [Int]
    private let labels = L10n.RecurrenceDisplay.weekdayShort

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.ParsedList.repeatOn)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            ForEach(1...7, id: \.self) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        selection.removeAll { $0 == day }
                    } else {
                        selection.append(day)
                        selection.sort()
                    }
                } label: {
                    Text(labels[day - 1])
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isSelected ? MacOS27Theme.primaryGradient : LinearGradient(colors: [Color.primary.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.28) : Color.clear,
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 每月重复细节配置
private struct MonthlyRecurrenceEditor: View {
    @Binding var item: ParsedItem
    private let weekdayLabels = L10n.RecurrenceDisplay.weekdays

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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Picker("", selection: Binding(get: { mode }, set: { switchMode($0) })) {
                Text(L10n.ParsedList.monthlyPlain).tag(0)
                Text(L10n.ParsedList.monthlyByDate).tag(1)
                Text(L10n.ParsedList.monthlyByNthWeekday).tag(2)
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)

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
                .font(.system(size: 11))

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
        .font(.system(size: 11))
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

/// 每年重复细节配置
private struct YearlyRecurrenceEditor: View {
    @Binding var item: ParsedItem

    var body: some View {
        HStack(spacing: 14) {
            Text(L10n.ParsedList.yearlyOn)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Stepper(
                L10n.ParsedList.monthNumber(item.recurrenceMonthsOfYear?.first ?? 3),
                value: Binding(
                    get: { item.recurrenceMonthsOfYear?.first ?? 3 },
                    set: { item.recurrenceMonthsOfYear = [$0] }
                ),
                in: 1...12
            )
            .font(.system(size: 11))
            
            Stepper(
                L10n.ParsedList.dayNumber(item.recurrenceDaysOfMonth?.first ?? 5),
                value: Binding(
                    get: { item.recurrenceDaysOfMonth?.first ?? 5 },
                    set: { item.recurrenceDaysOfMonth = [$0] }
                ),
                in: 1...31
            )
            .font(.system(size: 11))
        }
    }
}
