//
//  MacOS27Style.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  现代桌面端系统设计规范与通用视觉样式组件库
//

import SwiftUI

/// 现代桌面端设计规范颜色与渐变定义
enum MacOS27Theme {
    // MARK: - 强调色与微渐变
    
    /// 主功能高饱和度活力蓝渐变
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.48, blue: 0.98),
            Color(red: 0.05, green: 0.38, blue: 0.92)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 日历事件珊瑚橙金微渐变
    static let calendarGradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.45, blue: 0.25),
            Color(red: 0.95, green: 0.32, blue: 0.16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 提醒事项经典青蓝微渐变
    static let reminderGradient = LinearGradient(
        colors: [
            Color(red: 0.16, green: 0.58, blue: 1.00),
            Color(red: 0.08, green: 0.42, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 成功与确认翡翠薄荷绿渐变
    static let successGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.78, blue: 0.46),
            Color(red: 0.10, green: 0.65, blue: 0.36)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 警告与破坏操作玫瑰珊瑚红渐变
    static let dangerGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.32, blue: 0.36),
            Color(red: 0.88, green: 0.22, blue: 0.28)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 幽雅紫渐变（适用于周期规则等）
    static let purpleGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.38, blue: 0.96),
            Color(red: 0.52, green: 0.25, blue: 0.88)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 基础层级颜色
    
    /// 主卡片半透明底色（适配浅色与深色模式）
    static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.65)
    
    /// 微透明输入框底色
    static let inputBackground = Color(NSColor.textBackgroundColor).opacity(0.55)
    
    /// 边框描边颜色（带有微光高光与轮廓分割）
    static let subtleBorder = Color.primary.opacity(0.08)
    
    /// 悬停边框高光颜色
    static let hoverBorder = Color.accentColor.opacity(0.35)
}

// MARK: - 按钮交互样式定义

/// 现代主要操作高光胶囊按钮组件视图
private struct MacOS27PrimaryButtonContent: View {
    let configuration: ButtonStyle.Configuration
    var gradient: LinearGradient
    var isFullWidth: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                ZStack {
                    gradient
                    if isHovered {
                        Color.white.opacity(0.12)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            )
            .shadow(
                color: Color.accentColor.opacity(isHovered ? 0.32 : 0.18),
                radius: isHovered ? 6 : 3,
                x: 0,
                y: isHovered ? 3 : 1.5
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// 现代主要操作高光胶囊按钮样式
struct MacOS27PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = MacOS27Theme.primaryGradient
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        MacOS27PrimaryButtonContent(
            configuration: configuration,
            gradient: gradient,
            isFullWidth: isFullWidth
        )
    }
}

/// 现代次要操作半透明磨砂按钮组件视图
private struct MacOS27SecondaryButtonContent: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered: Bool = false

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? 0.16 : 0.08), lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// 现代次要操作半透明磨砂按钮样式
struct MacOS27SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MacOS27SecondaryButtonContent(configuration: configuration)
    }
}

/// 危险与清除操作半透明按钮组件视图
private struct MacOS27DestructiveButtonContent: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered: Bool = false

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(isHovered ? .white : Color(red: 0.95, green: 0.30, blue: 0.35))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? MacOS27Theme.dangerGradient : LinearGradient(colors: [Color.red.opacity(0.10)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.red.opacity(isHovered ? 0.3 : 0.15), lineWidth: 0.6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// 危险与清除操作半透明按钮样式
struct MacOS27DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MacOS27DestructiveButtonContent(configuration: configuration)
    }
}

/// 微型圆形图标按钮组件视图
private struct MacOS27CircleIconButtonContent: View {
    let configuration: ButtonStyle.Configuration
    var tintColor: Color
    var activeTintColor: Color
    var diameter: CGFloat
    @State private var isHovered: Bool = false

    var body: some View {
        configuration.label
            .foregroundColor(isHovered ? activeTintColor : tintColor)
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(isHovered ? 0.15 : 0.05), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovered ? 1.04 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// 微型圆形图标按钮样式（带轻盈半透明悬停衬底）
struct MacOS27CircleIconButtonStyle: ButtonStyle {
    var tintColor: Color = .secondary
    var activeTintColor: Color = .primary
    var diameter: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        MacOS27CircleIconButtonContent(
            configuration: configuration,
            tintColor: tintColor,
            activeTintColor: activeTintColor,
            diameter: diameter
        )
    }
}

// MARK: - 视图修饰器与容器组件

/// 现代桌面端卡片修饰器
struct MacOS27CardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isSelected: Bool = false
    var elevation: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.2 : 0.7
                    )
            )
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 3 * elevation,
                x: 0,
                y: 1.5 * elevation
            )
    }
}

/// 现代桌面端磨砂悬浮岛修饰器（用于输入框等核心展示区域）
struct MacOS27IslandModifier: ViewModifier {
    var isFocused: Bool = false
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.10),
                        lineWidth: isFocused ? 1.5 : 0.8
                    )
            )
            .shadow(
                color: isFocused ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.05),
                radius: isFocused ? 8 : 4,
                x: 0,
                y: isFocused ? 3 : 2
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

/// 胶囊徽标组件
struct MacOS27Badge: View {
    let text: String
    var icon: String? = nil
    var foregroundColor: Color = .primary
    var backgroundColor: Color = Color.primary.opacity(0.08)

    var body: some View {
        HStack(spacing: 3.5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(foregroundColor.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - 便捷扩展

extension View {
    /// 应用现代卡片质感
    func macOS27Card(cornerRadius: CGFloat = 12, isSelected: Bool = false, elevation: CGFloat = 1) -> some View {
        modifier(MacOS27CardModifier(cornerRadius: cornerRadius, isSelected: isSelected, elevation: elevation))
    }
    
    /// 应用现代输入岛容器质感
    func macOS27Island(isFocused: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        modifier(MacOS27IslandModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}
