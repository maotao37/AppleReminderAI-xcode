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
    
    /// 是否正在创建
    var isCreating: Bool
    
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
                Label("解析结果（\(items.count) 项）", systemImage: "list.bullet.rectangle")
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
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("全部创建")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreating)
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
                            Label(item.recurrence.rawValue, systemImage: item.recurrence.icon)
                                .font(.caption2)
                                .foregroundColor(.purple)
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
                    .help("移除此事项")
                    
                    // 展开/收起按钮
                    Button {
                        onToggleExpand()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isExpanded ? "收起详情" : "展开编辑")
                    
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
                    .help("创建此事项")
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
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $item.type) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 160)
                    }
                    
                    // 标题编辑
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("输入标题", text: $item.title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // 时间选择
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type == .calendar ? "开始时间" : "提醒时间")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: Binding(
                                get: { item.dueDate ?? Date() },
                                set: { item.dueDate = $0 }
                            ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.stepperField)
                        }
                        
                        if item.type == .calendar {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("结束时间")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: Binding(
                                    get: { item.endDate ?? (item.dueDate?.addingTimeInterval(3600) ?? Date()) },
                                    set: { item.endDate = $0 }
                                ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                            }
                        }
                        
                        // 全天切换
                        VStack(alignment: .leading, spacing: 4) {
                            Text("全天")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Toggle("", isOn: $item.isAllDay)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                    }
                    
                    // 重复周期和优先级
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("重复周期")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $item.recurrence) {
                                ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                                    Text(rule.rawValue).tag(rule)
                                }
                            }
                            .frame(width: 100)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("优先级")
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
                    
                    // 目标列表选择
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.type == .reminder ? "保存至提醒事项列表" : "保存至日历")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if item.type == .reminder {
                            Picker("", selection: $selectedReminderList) {
                                ForEach(reminderLists, id: \.calendarIdentifier) { list in
                                    Text(list.title).tag(Optional(list))
                                }
                            }
                        } else {
                            Picker("", selection: $selectedCalendar) {
                                ForEach(calendars, id: \.calendarIdentifier) { cal in
                                    Text(cal.title).tag(Optional(cal))
                                }
                            }
                        }
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
                            Text("确认创建并同步到苹果\(item.type.rawValue)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreating || item.title.isEmpty)
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
}
