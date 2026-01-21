//
//  SettingsView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  应用设置视图
//

import SwiftUI
import EventKit

/// 设置视图
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("应用设置")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 通用设置
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "通用设置", icon: "gearshape")
                        
                        // 使用与权限设置一致的样式
                        HStack {
                            Text("在状态栏显示")
                            Spacer()
                            Toggle("", isOn: $settings.isMenuBarVisible)
                                .labelsHidden()
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // 2. OpenAI 配置（始终显示，方便用户配置）
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "OpenAI 配置", icon: "key.fill")
                        
                        VStack(spacing: 12) {
                            SettingsInput(label: "API Key", text: $settings.openAIAPIKey, placeholder: "sk-...", isSecure: true)
                            SettingsInput(label: "API Base URL", text: $settings.openAIBaseURL, placeholder: "https://api.openai.com/v1")
                            SettingsInput(label: "AI 模型", text: $settings.openAIModel, placeholder: "gpt-4o-mini")
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                        
                        if !settings.isOpenAIConfigured {
                            Label("请配置 API Key 以使用 AI 解析功能", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    
                    // 3. 系统权限
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "系统权限", icon: "lock.shield.fill")
                        
                        VStack(spacing: 8) {
                            PermissionRow(
                                title: "提醒事项权限",
                                status: permissionManager.reminderStatus,
                                icon: permissionManager.statusIcon(for: permissionManager.reminderStatus),
                                color: permissionManager.statusColorName(for: permissionManager.reminderStatus),
                                description: permissionManager.statusDescription(for: permissionManager.reminderStatus),
                                onRequest: {
                                    Task { try? await permissionManager.requestReminderAccess() }
                                }
                            )
                            
                            PermissionRow(
                                title: "日历权限",
                                status: permissionManager.calendarStatus,
                                icon: permissionManager.statusIcon(for: permissionManager.calendarStatus),
                                color: permissionManager.statusColorName(for: permissionManager.calendarStatus),
                                description: permissionManager.statusDescription(for: permissionManager.calendarStatus),
                                onRequest: {
                                    Task { try? await permissionManager.requestCalendarAccess() }
                                }
                            )
                        }
                    }
                    
                    // 4. 关于
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "关于", icon: "info.circle.fill")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("苹果提醒事项 AI 助手")
                                .fontWeight(.semibold)
                            Text("版本 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("作者: mao.tao")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 600)
    }
}

/// 部分标题
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
        }
    }
}

/// 设置输入项
struct SettingsInput: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

/// 权限行组件
struct PermissionRow: View {
    let title: String
    let status: EKAuthorizationStatus
    let icon: String
    let color: String
    let description: String
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .foregroundColor(Color.from(name: color))
                        .font(.caption)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if status == .notDetermined {
                Button("去请求") {
                    onRequest()
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            } else if status == .denied || status == .restricted {
                Button("去设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

private extension Color {
    init(statusColor: String) {
        switch statusColor {
        case "green": self = .green
        case "red": self = .red
        case "orange": self = .orange
        case "gray": self = .gray
        default: self = .gray
        }
    }
}

private extension Color {
    static func from(name: String) -> Color {
        switch name {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "gray": return .gray
        default: return .secondary
        }
    }
}
