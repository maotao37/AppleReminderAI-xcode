//
//  MainViewModel.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  主视图模型
//  管理应用主界面的状态和业务逻辑
//

import Foundation
import SwiftUI
import EventKit
import Combine

/// 主视图模型
/// 负责管理输入解析、事项创建和历史记录
@MainActor
class MainViewModel: ObservableObject {
    
    // MARK: - 发布属性
    
    /// 用户输入的文本
    @Published var inputText: String = ""
    
    /// 解析后的事项数组（用于预览和编辑）
    @Published var parsedItems: [ParsedItem] = []
    
    /// 是否正在解析
    @Published var isParsing: Bool = false
    
    /// 是否正在创建
    @Published var isCreating: Bool = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 成功信息
    @Published var successMessage: String?
    
    /// 历史记录
    @Published var history: [CreatedItemRecord] = []
    
    /// 是否显示设置界面
    @Published var showSettings: Bool = false
    
    /// 可用的提醒事项列表
    @Published var reminderLists: [EKCalendar] = []
    
    /// 可用的日历列表
    @Published var calendars: [EKCalendar] = []
    
    /// 选中的提醒事项列表
    @Published var selectedReminderList: EKCalendar?
    
    /// 选中的日历
    @Published var selectedCalendar: EKCalendar?
    
    // MARK: - 私有属性
    
    private let permissionManager = PermissionManager.shared
    private let reminderService = ReminderService.shared
    private let calendarService = CalendarService.shared
    private let settings = AppSettings.shared
    
    /// Combine 订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    /// 历史记录存储键
    private let historyKey = "createdItemHistory"
    
    /// 最大历史记录数量
    private let maxHistoryCount = 50
    
    // MARK: - 初始化
    
    init() {
        loadHistory()
        loadAvailableLists()
        setupNotifications()
        setupParserModeObserver()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenSettings"), object: nil, queue: .main) { [weak self] _ in
            // 延迟执行以避免在视图更新期间修改状态
            DispatchQueue.main.async {
                self?.showSettings = true
            }
        }
    }
    
    /// 设置解析模式变化监听
    private func setupParserModeObserver() {
        settings.$parserMode
            .dropFirst() // 跳过初始值
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMode in
                guard let self = self else { return }
                
                // 清除之前的解析结果和消息
                self.parsedItems = []
                self.errorMessage = nil
                self.successMessage = nil
                
                // 如果切换到原生模式且输入框有内容，自动触发解析
                if newMode == .native && !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                        await self.parseInput()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 解析方法
    
    /// 解析输入文本
    func parseInput() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            parsedItems = []
            return
        }
        
        isParsing = true
        errorMessage = nil
        
        do {
            let parser = ParserFactory.createDefaultParser()
            let results = try await parser.parse(text)
            
            parsedItems = results
            
            if results.isEmpty {
                errorMessage = "无法解析输入内容，请尝试更具体的描述"
            }
        } catch let error as ParserError {
            errorMessage = error.localizedDescription
            parsedItems = []
        } catch {
            errorMessage = "解析失败: \(error.localizedDescription)"
            parsedItems = []
        }
        
        isParsing = false
    }
    
    /// 输入变化时自动解析（带防抖）
    private var parseTask: Task<Void, Never>?
    
    func onInputChanged() {
        // 取消之前的解析任务
        parseTask?.cancel()
        
        // 清除错误和成功信息
        errorMessage = nil
        successMessage = nil
        
        // 如果输入为空，清除解析结果
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsedItems = []
            return
        }
        
        // 只有在原生解析模式下才自动触发（带防抖）
        // AI 解析模式需要手动点击按钮触发，以节省 API 额度
        if settings.parserMode == .native {
            // 延迟 0.5 秒后开始解析
            parseTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                if !Task.isCancelled {
                    await parseInput()
                }
            }
        }
    }
    
    // MARK: - 创建方法
    
    /// 创建指定索引的事项
    /// - Parameter index: 要创建的事项索引
    func createItem(at index: Int) async {
        guard index >= 0 && index < parsedItems.count else { return }
        let item = parsedItems[index]
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        do {
            switch item.type {
            case .reminder:
                try await reminderService.createReminder(from: item, in: selectedReminderList)
                successMessage = "提醒事项已创建"
                
            case .calendar:
                try await calendarService.createEvent(from: item, in: selectedCalendar)
                successMessage = "日历事件已创建"
            }
            
            // 添加到历史记录
            addToHistory(item: item, success: true)
            
            // 从列表中移除已创建的事项
            parsedItems.remove(at: index)
            
            // 如果所有事项都已创建，清空输入
            if parsedItems.isEmpty {
                inputText = ""
            }
            
        } catch {
            errorMessage = error.localizedDescription
            addToHistory(item: item, success: false, error: error.localizedDescription)
        }
        
        isCreating = false
    }
    
    /// 创建所有解析的事项
    func createAllItems() async {
        guard !parsedItems.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        var successCount = 0
        var failCount = 0
        
        // 创建副本以便遍历时修改原数组
        let itemsToCreate = parsedItems
        
        for item in itemsToCreate {
            do {
                switch item.type {
                case .reminder:
                    try await reminderService.createReminder(from: item, in: selectedReminderList)
                case .calendar:
                    try await calendarService.createEvent(from: item, in: selectedCalendar)
                }
                
                addToHistory(item: item, success: true)
                successCount += 1
            } catch {
                addToHistory(item: item, success: false, error: error.localizedDescription)
                failCount += 1
            }
        }
        
        // 清空所有事项和输入
        parsedItems = []
        inputText = ""
        
        // 设置结果消息
        if failCount == 0 {
            successMessage = "成功创建 \(successCount) 个事项"
        } else {
            errorMessage = "创建完成：成功 \(successCount) 个，失败 \(failCount) 个"
        }
        
        isCreating = false
    }
    
    /// 删除指定索引的解析事项（不创建，仅从列表中移除）
    /// - Parameter index: 要删除的事项索引
    func removeItem(at index: Int) {
        guard index >= 0 && index < parsedItems.count else { return }
        parsedItems.remove(at: index)
        
        // 如果所有事项都被删除，清空输入
        if parsedItems.isEmpty {
            inputText = ""
        }
    }
    
    // MARK: - 列表管理
    
    /// 加载可用的列表
    func loadAvailableLists() {
        if permissionManager.hasReminderAccess {
            reminderLists = reminderService.fetchReminderLists()
            selectedReminderList = reminderService.defaultReminderList()
        }
        
        if permissionManager.hasCalendarAccess {
            calendars = calendarService.fetchCalendars()
            selectedCalendar = calendarService.defaultCalendar()
        }
    }
    
    // MARK: - 历史记录
    
    /// 添加到历史记录
    private func addToHistory(item: ParsedItem, success: Bool, error: String? = nil) {
        let record = CreatedItemRecord(item: item, isSuccess: success, errorMessage: error)
        history.insert(record, at: 0)
        
        // 限制历史记录数量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// 清除历史记录
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    /// 保存历史记录
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("保存历史记录失败: \(error)")
        }
    }
    
    /// 加载历史记录
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        
        do {
            history = try JSONDecoder().decode([CreatedItemRecord].self, from: data)
        } catch {
            print("加载历史记录失败: \(error)")
        }
    }
    
    // MARK: - 权限管理
    
    /// 请求权限
    func requestPermissions() async {
        do {
            try await permissionManager.requestAllPermissions()
            loadAvailableLists()
        } catch {
            errorMessage = "请求权限失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 编辑方法
    
    /// 更新指定索引的解析事项
    /// - Parameters:
    ///   - item: 更新后的事项
    ///   - index: 事项索引
    func updateParsedItem(_ item: ParsedItem, at index: Int) {
        guard index >= 0 && index < parsedItems.count else { return }
        parsedItems[index] = item
    }
    
    /// 切换指定索引事项的类型
    /// - Parameter index: 事项索引
    func toggleItemType(at index: Int) {
        guard index >= 0 && index < parsedItems.count else { return }
        parsedItems[index].type = parsedItems[index].type == .reminder ? .calendar : .reminder
    }
}
