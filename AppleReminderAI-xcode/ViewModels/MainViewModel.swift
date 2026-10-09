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

    /// 批量创建进度（第 N 个 / 共 M 个），仅批量创建期间非 nil
    @Published var creationProgress: (current: Int, total: Int)?

    /// 历史记录加载失败提示（数据损坏时告知用户，不再静默丢弃）
    @Published var historyLoadWarning: String?
    
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

    /// 当前进行中的解析任务（AI 模式手动触发，支持取消）
    private var activeParseTask: Task<Void, Never>?

    /// Prevents an older parser request from overwriting newer input.
    private var parseGeneration = 0
    
    // MARK: - 初始化
    
    init() {
        loadHistory()
        loadAvailableLists()
        setupNotifications()
        setupParserModeObserver()
        setupHistoryLimitObserver()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .openSettingsRequest, object: nil, queue: .main) { [weak self] _ in
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
                self.parseGeneration += 1
                self.isParsing = false
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
    
    /// 设置历史记录上限变化监听：缩小上限时立即裁剪已存记录
    private func setupHistoryLimitObserver() {
        settings.$historyLimit
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] limit in
                guard let self = self, self.history.count > limit else { return }
                self.history = Array(self.history.prefix(limit))
                self.saveHistory()
            }
            .store(in: &cancellables)
    }

    // MARK: - 解析方法

    /// 手动触发解析（AI 解析按钮 / ⌘↵ 调用），任务可被 cancelParsing() 取消
    func startParsing() {
        activeParseTask?.cancel()
        activeParseTask = Task { await parseInput() }
    }

    /// 取消进行中的 AI 解析（网络慢时不必干等超时）
    func cancelParsing() {
        activeParseTask?.cancel()
        activeParseTask = nil
        parseGeneration += 1
        isParsing = false
    }

    /// 解析输入文本
    func parseInput() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            parsedItems = []
            return
        }
        
        parseGeneration += 1
        let generation = parseGeneration
        let parserMode = settings.parserMode
        isParsing = true
        errorMessage = nil
        
        do {
            let parser = ParserFactory.createDefaultParser(
                reminderGroupNames: reminderLists.map(\.title),
                calendarGroupNames: calendars.map(\.title)
            )
            let results = try await parser.parse(text)

            guard generation == parseGeneration,
                  parserMode == settings.parserMode,
                  text == inputText.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }

            parsedItems = results.map(assignGroup)
            
            if results.isEmpty {
                errorMessage = L10n.Message.unparseable
            }
        } catch is CancellationError {
            // 用户主动取消：不算错误，保留当前内容
            guard generation == parseGeneration else { return }
            errorMessage = nil
        } catch let error as ParserError {
            guard generation == parseGeneration else { return }
            errorMessage = error.localizedDescription
            parsedItems = []
        } catch {
            guard generation == parseGeneration else { return }
            errorMessage = L10n.Message.parseFailed(error.localizedDescription)
            parsedItems = []
        }

        if generation == parseGeneration {
            isParsing = false
        }
    }
    
    /// 输入变化时自动解析（带防抖）
    private var parseTask: Task<Void, Never>?
    
    func onInputChanged() {
        // 取消之前的解析任务
        parseTask?.cancel()
        parseGeneration += 1
        isParsing = false
        
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
        let item = assignGroup(ScheduleNormalizer.normalize(parsedItems[index]))
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let identifier = try await create(item)
            successMessage = item.type == .reminder ? L10n.Message.reminderCreated : L10n.Message.eventCreated
            addToHistory(item: item, success: true, calendarItemIdentifier: identifier)

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
        var failedItems: [ParsedItem] = []
        
        // 创建副本以便遍历时修改原数组
        let itemsToCreate = parsedItems
        creationProgress = (0, itemsToCreate.count)

        for (index, source) in itemsToCreate.enumerated() {
            creationProgress = (index + 1, itemsToCreate.count)
            let item = assignGroup(ScheduleNormalizer.normalize(source))
            do {
                let identifier = try await create(item)
                addToHistory(item: item, success: true, calendarItemIdentifier: identifier)
                successCount += 1
            } catch {
                addToHistory(item: item, success: false, error: error.localizedDescription)
                failedItems.append(item)
                failCount += 1
            }
        }

        parsedItems = failedItems
        if failedItems.isEmpty {
            inputText = ""
        }

        // 设置结果消息
        if failCount == 0 {
            successMessage = L10n.Message.created(successCount)
        } else {
            errorMessage = L10n.Message.createPartialResult(success: successCount, failure: failCount)
        }

        creationProgress = nil
        isCreating = false
    }

    private func create(_ item: ParsedItem) async throws -> String? {
        switch item.type {
        case .reminder:
            if !permissionManager.hasReminderAccess {
                _ = try await permissionManager.requestReminderAccess()
                loadAvailableLists()
            }
            let resolvedItem = assignGroup(item)
            let target = resolvedItem.targetGroupIdentifier.flatMap { reminderService.getReminderList(by: $0) } ?? selectedReminderList
            let reminder = try await reminderService.createReminder(from: resolvedItem, in: target)
            return reminder.calendarItemIdentifier

        case .calendar:
            if !permissionManager.hasCalendarAccess {
                _ = try await permissionManager.requestCalendarAccess()
                loadAvailableLists()
            }
            let resolvedItem = assignGroup(item)
            let target = resolvedItem.targetGroupIdentifier.flatMap { calendarService.getCalendar(by: $0) } ?? selectedCalendar
            let event = try await calendarService.createEvent(from: resolvedItem, in: target)
            return event.calendarItemIdentifier
        }
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
            if selectedReminderList == nil || !reminderLists.contains(where: { $0.calendarIdentifier == selectedReminderList?.calendarIdentifier }) {
                selectedReminderList = reminderService.defaultReminderList()
            }
        }
        
        if permissionManager.hasCalendarAccess {
            calendars = calendarService.fetchCalendars()
            if selectedCalendar == nil || !calendars.contains(where: { $0.calendarIdentifier == selectedCalendar?.calendarIdentifier }) {
                selectedCalendar = calendarService.defaultCalendar()
            }
        }

        parsedItems = parsedItems.map(assignGroup)
    }

    private func assignGroup(_ item: ParsedItem) -> ParsedItem {
        GroupClassifier.assign(
            item,
            reminderLists: reminderLists,
            calendars: calendars,
            defaultReminderList: selectedReminderList ?? reminderService.defaultReminderList(),
            defaultCalendar: selectedCalendar ?? calendarService.defaultCalendar()
        )
    }
    
    // MARK: - 历史记录
    
    /// 添加到历史记录
    private func addToHistory(
        item: ParsedItem,
        success: Bool,
        error: String? = nil,
        calendarItemIdentifier: String? = nil
    ) {
        let record = CreatedItemRecord(
            item: item,
            isSuccess: success,
            errorMessage: error,
            calendarItemIdentifier: calendarItemIdentifier
        )
        history.insert(record, at: 0)

        // 限制历史记录数量（用户可在设置中调整上限）
        let limit = settings.historyLimit
        if history.count > limit {
            history = Array(history.prefix(limit))
        }

        saveHistory()
    }
    
    /// 清除历史记录
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func retryHistoryItem(id: UUID) {
        guard let record = history.first(where: { $0.id == id }) else { return }
        let item = assignGroup(ScheduleNormalizer.normalize(record.item))
        if !parsedItems.contains(where: { $0.id == item.id }) {
            parsedItems.append(item)
        }
        errorMessage = nil
        successMessage = L10n.Message.retryQueued
    }

    func undoHistoryItem(id: UUID) async {
        guard let index = history.firstIndex(where: { $0.id == id }),
              history[index].isSuccess,
              !history[index].isUndone,
              let identifier = history[index].calendarItemIdentifier else {
            return
        }

        do {
            switch history[index].item.type {
            case .reminder:
                try reminderService.removeReminder(identifier: identifier)
            case .calendar:
                try calendarService.removeEvent(identifier: identifier)
            }
            history[index].undoneAt = Date()
            saveHistory()
            successMessage = L10n.Message.undone
            errorMessage = nil
        } catch {
            errorMessage = L10n.Message.undoFailed(error.localizedDescription)
        }
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
            // 解析失败时保留原始数据不覆盖，并向用户提示
            print("加载历史记录失败: \(error)")
            historyLoadWarning = L10n.Message.historyLoadFailed
        }
    }
    
    // MARK: - 权限管理
    
    /// 请求权限
    func requestPermissions() async {
        do {
            try await permissionManager.requestAllPermissions()
            loadAvailableLists()
        } catch {
            errorMessage = L10n.Message.requestPermissionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 编辑方法
    
    /// 更新指定索引的解析事项
    /// - Parameters:
    ///   - item: 更新后的事项
    ///   - index: 事项索引
    func updateParsedItem(_ item: ParsedItem, at index: Int) {
        guard index >= 0 && index < parsedItems.count else { return }
        parsedItems[index] = ScheduleNormalizer.normalize(item)
    }
    
    /// 设置指定索引事项的类型（提醒事项/日历事件）
    /// 单次原子更新：切换类型 → 重置分组 → 归一化 → 重新自动分组
    func setItemType(_ newType: ItemType, at index: Int) {
        guard index >= 0 && index < parsedItems.count else { return }
        parsedItems[index].type = newType
        parsedItems[index].targetGroupIdentifier = nil
        parsedItems[index].targetGroupName = nil
        parsedItems[index] = assignGroup(ScheduleNormalizer.normalize(parsedItems[index]))
    }
}
