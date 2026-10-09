//
//  AppSettings.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  应用设置模型
//

import Foundation
import Combine
import AppKit

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
        static let historyLimit = "historyLimit"
    }

    private static let apiKeyAccount = "openAIAPIKey"
    
    // MARK: - 单例
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard

    /// Combine 订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 解析设置
    
    /// 当前解析模式
    @Published var parserMode: ParserMode {
        didSet {
            defaults.set(parserMode.rawValue, forKey: Keys.parserMode)
        }
    }
    
    // MARK: - OpenAI 设置
    
    /// OpenAI API Key
    /// 注意：Keychain 写入经防抖后执行，避免输入每个字符都触发一次磁盘加密写入
    @Published var openAIAPIKey: String
    
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

    // MARK: - 历史记录设置

    /// 历史记录保留条数上限
    @Published var historyLimit: Int {
        didSet {
            defaults.set(historyLimit, forKey: Keys.historyLimit)
        }
    }
    
    // MARK: - 初始化
    
    private init() {
        // 从 UserDefaults 加载设置
        let modeRaw = defaults.string(forKey: Keys.parserMode) ?? ParserMode.native.rawValue
        self.parserMode = ParserMode(rawValue: modeRaw) ?? .native
        
        let legacyAPIKey = defaults.string(forKey: Keys.openAIAPIKey) ?? ""
        let keychainAPIKey = KeychainStore.string(for: Self.apiKeyAccount)
        self.openAIAPIKey = keychainAPIKey ?? legacyAPIKey
        if !legacyAPIKey.isEmpty {
            if keychainAPIKey == nil {
                KeychainStore.set(legacyAPIKey, for: Self.apiKeyAccount)
            }
            defaults.removeObject(forKey: Keys.openAIAPIKey)
        }
        self.openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL) ?? "https://api.openai.com/v1"
        self.openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o-mini"
        self.isMenuBarVisible = defaults.object(forKey: Keys.isMenuBarVisible) as? Bool ?? true
        
        self.defaultReminderListID = defaults.string(forKey: Keys.defaultReminderListID)
        self.defaultCalendarID = defaults.string(forKey: Keys.defaultCalendarID)
        self.historyLimit = defaults.object(forKey: Keys.historyLimit) as? Int ?? 50

        setupAPIKeyPersistence()
    }

    /// API Key 防抖写入 Keychain：停止输入 0.5 秒或应用退出时落盘
    private func setupAPIKeyPersistence() {
        $openAIAPIKey
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                KeychainStore.set(value, for: Self.apiKeyAccount)
            }
            .store(in: &cancellables)

        // 退出时立即落盘，避免防抖窗口内的最后输入丢失
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                KeychainStore.set(self.openAIAPIKey, for: Self.apiKeyAccount)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 便捷方法
    
    /// 检查 OpenAI 配置是否有效
    var isOpenAIConfigured: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validatedOpenAIBaseURL != nil
    }

    /// Remote endpoints must use TLS. Plain HTTP is allowed only for local model servers.
    var validatedOpenAIBaseURL: URL? {
        guard let url = URL(string: openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else {
            return nil
        }

        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard scheme == "https" || (scheme == "http" && isLoopback) else { return nil }
        return url
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
        historyLimit = 50
    }
}
