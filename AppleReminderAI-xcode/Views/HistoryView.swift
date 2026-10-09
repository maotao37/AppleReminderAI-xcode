//
//  HistoryView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  创建记录历史视图
//

import SwiftUI

/// 历史记录视图
struct HistoryView: View {
    let history: [CreatedItemRecord]
    /// 历史记录加载提示
    var loadWarning: String? = nil
    var onClear: () -> Void
    var onRetry: (UUID) -> Void
    var onUndo: (UUID) -> Void
    @State private var isConfirmingClear = false
    /// 待撤销的重复日历事件
    @State private var pendingUndoRecord: CreatedItemRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部操作栏
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(L10n.History.title)
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

                if !history.isEmpty {
                    Button {
                        isConfirmingClear = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .semibold))
                            Text(L10n.History.clear)
                        }
                    }
                    .buttonStyle(MacOS27DestructiveButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            // 数据加载异常警示提示
            if let loadWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(loadWarning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 0.6)
                )
                .padding(.horizontal, 16)
            }

            // 空状态或列表展示
            if history.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: 58, height: 58)
                        
                        Image(systemName: "tray.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.accentColor.opacity(0.8))
                    }
                    
                    VStack(spacing: 3) {
                        Text(L10n.History.empty)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history) { record in
                            HistoryRow(
                                record: record,
                                onRetry: { onRetry(record.id) },
                                onUndo: { requestUndo(record) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .confirmationDialog(L10n.History.clearConfirmTitle, isPresented: $isConfirmingClear) {
            Button(L10n.History.clear, role: .destructive, action: onClear)
        }
        .confirmationDialog(
            L10n.History.undoRecurringTitle,
            isPresented: Binding(
                get: { pendingUndoRecord != nil },
                set: { if !$0 { pendingUndoRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.History.undoRecurringAction, role: .destructive) {
                if let record = pendingUndoRecord {
                    onUndo(record.id)
                }
                pendingUndoRecord = nil
            }
            Button(L10n.Common.cancel, role: .cancel) {
                pendingUndoRecord = nil
            }
        } message: {
            Text(L10n.History.undoRecurringMessage(pendingUndoRecord?.item.title ?? ""))
        }
    }

    /// 撤销处理逻辑
    private func requestUndo(_ record: CreatedItemRecord) {
        if record.item.type == .calendar, record.item.recurrence != .none {
            pendingUndoRecord = record
        } else {
            onUndo(record.id)
        }
    }
}

/// 历史记录单行组件
struct HistoryRow: View {
    let record: CreatedItemRecord
    var onRetry: () -> Void
    var onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 事项类型徽章
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(record.item.type == .reminder ? MacOS27Theme.reminderGradient : MacOS27Theme.calendarGradient)
                    .frame(width: 32, height: 32)
                    .shadow(
                        color: (record.item.type == .reminder ? Color.blue : Color.orange).opacity(0.2),
                        radius: 2.5,
                        x: 0,
                        y: 1
                    )
                
                Image(systemName: record.item.type == .reminder ? "checkmark" : "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 标题与副信息
            VStack(alignment: .leading, spacing: 3) {
                Text(record.item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let date = record.item.dueDate {
                        Text(formatDate(date))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if record.item.recurrence != .none {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(record.item.recurrence.rawValue)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    if let groupName = record.item.targetGroupName {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Label(groupName, systemImage: "folder")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.teal)
                    }
                }
            }
            
            Spacer()
            
            // 状态与创建时间胶囊
            VStack(alignment: .trailing, spacing: 3) {
                if record.isUndone {
                    MacOS27Badge(
                        text: "已撤销",
                        icon: "arrow.uturn.backward",
                        foregroundColor: .secondary,
                        backgroundColor: Color.primary.opacity(0.06)
                    )
                } else if record.isSuccess {
                    MacOS27Badge(
                        text: "成功",
                        icon: "checkmark",
                        foregroundColor: Color(red: 0.15, green: 0.75, blue: 0.45),
                        backgroundColor: Color.green.opacity(0.08)
                    )
                } else {
                    MacOS27Badge(
                        text: "失败",
                        icon: "exclamationmark.circle",
                        foregroundColor: Color(red: 0.95, green: 0.30, blue: 0.35),
                        backgroundColor: Color.red.opacity(0.08)
                    )
                }
                
                Text(formatTime(record.createdAt))
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            // 动作按钮（重试/撤销）
            if !record.isSuccess {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(MacOS27CircleIconButtonStyle(
                    tintColor: Color(red: 0.95, green: 0.30, blue: 0.35),
                    activeTintColor: .white,
                    diameter: 26
                ))
                .help(L10n.History.retryHelp)
            } else if !record.isUndone, record.calendarItemIdentifier != nil {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(MacOS27CircleIconButtonStyle(
                    tintColor: .secondary,
                    activeTintColor: .primary,
                    diameter: 26
                ))
                .help(L10n.History.undoHelp)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .macOS27Card(cornerRadius: 10)
        .help(record.errorMessage ?? (record.isUndone ? L10n.History.statusUndone : (record.isSuccess ? L10n.History.statusSuccess : L10n.History.statusFailed)))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
