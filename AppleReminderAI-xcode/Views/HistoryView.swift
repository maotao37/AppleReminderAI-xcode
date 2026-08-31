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
    var onClear: () -> Void
    var onRetry: (UUID) -> Void
    var onUndo: (UUID) -> Void
    @State private var isConfirmingClear = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("最近创建", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !history.isEmpty {
                    Button("清空记录") {
                        isConfirmingClear = true
                    }
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无创建记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(history) { record in
                            HistoryRow(
                                record: record,
                                onRetry: { onRetry(record.id) },
                                onUndo: { onUndo(record.id) }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .confirmationDialog("清空所有创建记录？", isPresented: $isConfirmingClear) {
            Button("清空记录", role: .destructive, action: onClear)
        }
    }
}

/// 历史记录行组件
struct HistoryRow: View {
    let record: CreatedItemRecord
    var onRetry: () -> Void
    var onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(record.item.type == .reminder ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: record.item.type == .reminder ? "checkmark.circle" : "calendar")
                    .foregroundColor(record.item.type == .reminder ? .blue : .red)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.item.title)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let date = record.item.dueDate {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if record.item.recurrence != .none {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(record.item.recurrence.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let groupName = record.item.targetGroupName {
                        Text("•")
                            .foregroundColor(.secondary)
                        Label(groupName, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 状态
            VStack(alignment: .trailing, spacing: 2) {
                if record.isUndone {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.secondary)
                } else if record.isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                
                Text(formatTime(record.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }


            if !record.isSuccess {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新编辑并创建")
            } else if !record.isUndone, record.calendarItemIdentifier != nil {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("撤销创建")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .help(record.errorMessage ?? (record.isUndone ? "已撤销" : (record.isSuccess ? "已成功创建" : "创建失败")))
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
