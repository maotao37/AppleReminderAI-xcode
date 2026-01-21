//
//  AppSettings.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  应用设置模型
//

import Foundation
import Combine

/// 解析模式枚举
enum ParserMode: String, CaseIterable, Codable {
    case native = "原生解析"
    case openAI = "AI解析"
    
    var description: String {
        switch self {
        case .native:
            return "使用系统内置的自然语言处理，离线可用"
        case .openAI:
            return "使用 OpenAI API 进行智能解析，需要网络连接"
        }
    }
    
    var icon: String {
        switch self {
        case .native:
            return "cpu"
        case .openAI:
            return "brain"
        }
    }
}

/// 应用设置模型
/// 使用 @AppStorage 持久化存储
class AppSettings: ObservableObject {
    // MARK: - 存储键
    private enum Keys {
        static let parserMode = "parserMode"
        static let openAIAPIKey = "openAIAPIKey"
        static let openAIBaseURL = "openAIBaseURL"
        static let openAIModel = "openAIModel"
        static let defaultReminderListID = "defaultReminderListID"
        static let defaultCalendarID = "defaultCalendarID"
        static let isMenuBarVisible = "isMenuBarVisible"
    }
    
    // MARK: - 单例
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - 解析设置
    
    /// 当前解析模式
    @Published var parserMode: ParserMode {
        didSet {
            defaults.set(parserMode.rawValue, forKey: Keys.parserMode)
        }
    }
    
    // MARK: - OpenAI 设置
    
    /// OpenAI API Key
    @Published var openAIAPIKey: String {
        didSet {
            defaults.set(openAIAPIKey, forKey: Keys.openAIAPIKey)
        }
    }
    
    /// OpenAI API Base URL（支持自定义端点）
    @Published var openAIBaseURL: String {
        didSet {
            defaults.set(openAIBaseURL, forKey: Keys.openAIBaseURL)
        }
    }
    
    /// OpenAI 模型名称
    @Published var openAIModel: String {
        didSet {
            defaults.set(openAIModel, forKey: Keys.openAIModel)
        }
    }
    
    // MARK: - 状态栏设置
    
    /// 是否在状态栏显示
    @Published var isMenuBarVisible: Bool {
        didSet {
            defaults.set(isMenuBarVisible, forKey: Keys.isMenuBarVisible)
        }
    }
    
    // MARK: - 默认列表设置
    
    /// 默认提醒事项列表 ID
    @Published var defaultReminderListID: String? {
        didSet {
            defaults.set(defaultReminderListID, forKey: Keys.defaultReminderListID)
        }
    }
    
    /// 默认日历 ID
    @Published var defaultCalendarID: String? {
        didSet {
            defaults.set(defaultCalendarID, forKey: Keys.defaultCalendarID)
        }
    }
    
    // MARK: - 初始化
    
    private init() {
        // 从 UserDefaults 加载设置
        let modeRaw = defaults.string(forKey: Keys.parserMode) ?? ParserMode.native.rawValue
        self.parserMode = ParserMode(rawValue: modeRaw) ?? .native
        
        self.openAIAPIKey = defaults.string(forKey: Keys.openAIAPIKey) ?? ""
        self.openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL) ?? "https://api.openai.com/v1"
        self.openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o-mini"
        self.isMenuBarVisible = defaults.object(forKey: Keys.isMenuBarVisible) as? Bool ?? true
        
        self.defaultReminderListID = defaults.string(forKey: Keys.defaultReminderListID)
        self.defaultCalendarID = defaults.string(forKey: Keys.defaultCalendarID)
    }
    
    // MARK: - 便捷方法
    
    /// 检查 OpenAI 配置是否有效
    var isOpenAIConfigured: Bool {
        !openAIAPIKey.isEmpty && !openAIBaseURL.isEmpty
    }
    
    /// 重置所有设置为默认值
    func resetToDefaults() {
        parserMode = .native
        openAIAPIKey = ""
        openAIBaseURL = "https://api.openai.com/v1"
        openAIModel = "gpt-4o-mini"
        isMenuBarVisible = true
        defaultReminderListID = nil
        defaultCalendarID = nil
    }
}
