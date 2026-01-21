//
//  PreviewView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  解析结果预览与编辑视图
//

import SwiftUI
import EventKit

/// 解析结果预览视图
struct PreviewView: View {
    @Binding var item: ParsedItem
    var onConfirm: () -> Void
    var isCreating: Bool
    
    // 列表数据
    var reminderLists: [EKCalendar]
    var calendars: [EKCalendar]
    @Binding var selectedReminderList: EKCalendar?
    @Binding var selectedCalendar: EKCalendar?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和类型切换
            HStack {
                Label("解析结果预览", systemImage: "eye")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 类型切换按钮
                Picker("", selection: $item.type) {
                    ForEach(ItemType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            
            Divider()
            
            // 编辑表单内容
            VStack(alignment: .leading, spacing: 12) {
                // 标题编辑
                VStack(alignment: .leading, spacing: 4) {
                    Text("标题")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入标题", text: $item.title)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.title3)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // 时间选择区域
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        // 开始时间 / 截止时间
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type == .calendar ? "开始时间" : "提醒时间")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: Binding(
                                get: { item.dueDate ?? Date() },
                                set: { 
                                    item.dueDate = $0
                                    // 如果是日历事件且设置了结束时间，且结束时间早于开始时间，则同步更新结束时间
                                    if item.type == .calendar, let end = item.endDate, end < $0 {
                                        item.endDate = $0.addingTimeInterval(3600)
                                    }
                                }
                            ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.stepperField)
                        }
                        
                        // 结束时间 (仅日历事件显示)
                        if item.type == .calendar {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("结束时间")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: Binding(
                                    get: { item.endDate ?? (item.dueDate?.addingTimeInterval(3600) ?? Date().addingTimeInterval(3600)) },
                                    set: { item.endDate = $0 }
                                ), displayedComponents: item.isAllDay ? [.date] : [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                            }
                        }
                        
                        Spacer()
                        
                        // 是否全天
                        VStack(alignment: .leading, spacing: 4) {
                            Text("全天")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Toggle("", isOn: $item.isAllDay)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                    }
                    
                    HStack(spacing: 20) {
                        // 重复周期
                        VStack(alignment: .leading, spacing: 4) {
                            Text("重复周期")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            RecurrencePickerView(selection: $item.recurrence)
                        }
                        
                        // 优先级
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
                        
                        Spacer()
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
                
                // 备注编辑
                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入备注（可选）", text: Binding(
                        get: { item.notes ?? "" },
                        set: { item.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Spacer(minLength: 16)
            
            // 确认按钮
            Button(action: onConfirm) {
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
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isCreating || item.title.isEmpty)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
