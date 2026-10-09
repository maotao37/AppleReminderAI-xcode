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
            // 顶部导航栏
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(L10n.Settings.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Button(L10n.Common.done) {
                    dismiss()
                }
                .buttonStyle(MacOS27PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Color(NSColor.windowBackgroundColor)
                    .opacity(0.85)
            )
            
            Divider()
                .opacity(0.5)
            
            // 设置内容滚动区
            ScrollView {
                VStack(spacing: 18) {
                    // 1. 通用设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: L10n.Settings.general, icon: "slider.horizontal.3", iconGradient: MacOS27Theme.primaryGradient)
                        
                        VStack(spacing: 8) {
                            // 菜单栏常驻开关
                            HStack {
                                Text(L10n.Settings.menuBar)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Toggle("", isOn: $settings.isMenuBarVisible)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )

                            // 历史记录保存上限
                            HStack {
                                Text(L10n.Settings.historyLimit)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Picker("", selection: $settings.historyLimit) {
                                    ForEach([10, 20, 50, 100, 200], id: \.self) { limit in
                                        Text(L10n.Settings.limitOption(limit)).tag(limit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )
                        }
                    }
                    .padding(14)
                    .macOS27Card(cornerRadius: 12)
                    
                    // 2. 接口服务配置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: L10n.Settings.openAISection, icon: "key.fill", iconGradient: MacOS27Theme.purpleGradient)
                        
                        VStack(spacing: 10) {
                            SettingsInput(label: L10n.Settings.apiKeyField, text: $settings.openAIAPIKey, placeholder: "sk-...", isSecure: true)
                            SettingsInput(label: L10n.Settings.baseURLField, text: $settings.openAIBaseURL, placeholder: "https://api.openai.com/v1")
                            SettingsInput(label: L10n.Settings.modelField, text: $settings.openAIModel, placeholder: "gpt-4o-mini")
                        }
                        
                        if !settings.isOpenAIConfigured {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text(L10n.Settings.notConfiguredWarning)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(L10n.Settings.privacyNote)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                    .padding(14)
                    .macOS27Card(cornerRadius: 12)
                    
                    // 3. 系统权限卡片
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: L10n.Settings.permissions, icon: "hand.raised.fill", iconGradient: MacOS27Theme.calendarGradient)
                        
                        VStack(spacing: 8) {
                            PermissionRow(
                                title: L10n.Settings.reminderPermission,
                                status: permissionManager.reminderStatus,
                                icon: permissionManager.statusIcon(for: permissionManager.reminderStatus),
                                color: permissionManager.statusColorName(for: permissionManager.reminderStatus),
                                description: permissionManager.statusDescription(for: permissionManager.reminderStatus),
                                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
                                onRequest: {
                                    Task { try? await permissionManager.requestReminderAccess() }
                                }
                            )
                            
                            PermissionRow(
                                title: L10n.Settings.calendarPermission,
                                status: permissionManager.calendarStatus,
                                icon: permissionManager.statusIcon(for: permissionManager.calendarStatus),
                                color: permissionManager.statusColorName(for: permissionManager.calendarStatus),
                                description: permissionManager.statusDescription(for: permissionManager.calendarStatus),
                                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
                                onRequest: {
                                    Task { try? await permissionManager.requestCalendarAccess() }
                                }
                            )
                        }
                    }
                    .padding(14)
                    .macOS27Card(cornerRadius: 12)
                    
                    // 4. 关于卡片
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: L10n.Settings.about, icon: "info.circle.fill", iconGradient: MacOS27Theme.successGradient)
                        
                        HStack(spacing: 14) {
                            // 应用小图标徽标
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(MacOS27Theme.primaryGradient)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 3, x: 0, y: 1.5)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("苹果提醒事项智能助理")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                
                                HStack(spacing: 8) {
                                    Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    
                                    Text("作者: mao.tao")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.02))
                        )
                    }
                    .padding(14)
                    .macOS27Card(cornerRadius: 12)
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 620)
        .background(Color(NSColor.underPageBackgroundColor).opacity(0.5))
    }
}

/// 分组标题组件
struct SectionHeader: View {
    let title: String
    let icon: String
    var iconGradient: LinearGradient = MacOS27Theme.primaryGradient
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconGradient)
                    .frame(width: 22, height: 22)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
        }
    }
}

/// 设置项输入框
struct SettingsInput: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12.5))
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
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12.5))
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
    let settingsURL: String
    let onRequest: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .foregroundColor(Color.from(name: color))
                        .font(.system(size: 10.5))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if status == .notDetermined {
                Button(L10n.Settings.requestPermission) {
                    onRequest()
                }
                .buttonStyle(MacOS27SecondaryButtonStyle())
            } else if status == .denied || status == .restricted {
                Button(L10n.Settings.openSystemSettings) {
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(MacOS27SecondaryButtonStyle())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
                        .font(.system(size: 13))
                    Text("已授权")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

private extension Color {
    static func from(name: String) -> Color {
        switch name {
        case "green": return Color(red: 0.15, green: 0.75, blue: 0.45)
        case "red": return Color(red: 0.95, green: 0.30, blue: 0.35)
        case "orange": return Color.orange
        case "gray": return Color.gray
        default: return Color.secondary
        }
    }
}
