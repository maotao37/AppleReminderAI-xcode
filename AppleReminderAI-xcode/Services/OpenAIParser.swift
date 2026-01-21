//
//  OpenAIParser.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  OpenAI 智能解析器
//  通过调用 OpenAI API 进行自然语言解析
//

import Foundation

/// OpenAI 智能解析器
/// 调用 OpenAI Chat Completion API 进行更智能的自然语言解析
class OpenAIParser: ItemParser {
    
    // MARK: - ItemParser 协议属性
    
    var name: String { "AI 解析器" }
    var description: String { "使用 OpenAI API 进行智能解析，支持更复杂的自然语言表达" }
    var requiresNetwork: Bool { true }
    
    // MARK: - 私有属性
    
    private let settings = AppSettings.shared
    
    /// API 请求超时时间
    private let timeoutInterval: TimeInterval = 30
    
    // MARK: - 解析方法
    
    func parse(_ input: String) async throws -> [ParsedItem] {
        // 检查输入是否为空
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw ParserError.emptyInput
        }
        
        // 检查 API Key 是否配置
        guard settings.isOpenAIConfigured else {
            throw ParserError.invalidAPIKey
        }
        
        // 构建请求
        let request = try buildRequest(for: trimmedInput)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParserError.parseFailure("无效的响应")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try parseResponse(data, originalText: trimmedInput)
        case 401:
            throw ParserError.invalidAPIKey
        case 429:
            throw ParserError.rateLimitExceeded
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ParserError.parseFailure("API 错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }
    }
    
    // MARK: - 请求构建
    
    /// 构建 API 请求
    private func buildRequest(for input: String) throws -> URLRequest {
        guard let url = URL(string: "\(settings.openAIBaseURL)/chat/completions") else {
            throw ParserError.parseFailure("无效的 API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("Bearer \(settings.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 获取当前日期信息用于上下文
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年M月d日 EEEE"
        let currentDateStr = dateFormatter.string(from: Date())
        
        // 构建系统提示词（支持解析多个事项）
        let systemPrompt = """
        你是一个专业的日程解析助手。用户会输入自然语言描述的提醒事项或日历事件，你需要解析并提取关键信息。
        一段输入中可能包含多个事项，请全部解析出来。

        当前时间：\(currentDateStr)

        请将用户输入解析为以下 JSON 格式（严格遵循此格式，返回事项数组）：
        {
            "items": [
                {
                    "type": "reminder" 或 "calendar",
                    "title": "事项标题",
                    "notes": "备注（可选，可为 null）",
                    "dueDate": "ISO 8601 格式的日期时间，如 2026-01-20T15:00:00",
                    "endDate": "结束时间（仅日历事件需要，可为 null）",
                    "isAllDay": true 或 false,
                    "priority": 0-9 的数字（0=无，1-4=高，5=中，6-9=低），
                    "recurrence": "none", "daily", "weekly", "biweekly", "monthly", 或 "yearly",
                    "confidence": 0.0 到 1.0 的置信度
                }
            ]
        }

        解析规则：
        1. 如果包含"会议"、"开会"、"约会"、"出差"等词，type 应为 "calendar"
        2. 如果包含"提醒"、"记得"、"别忘了"等词，type 应为 "reminder"
        3. 默认 type 为 "reminder"
        4. 仔细解析时间表达，如"明天"、"下周一"、"每周五"等
        5. 如果没有具体时间只有日期，isAllDay 应为 true
        6. 用户输入可能包含多个事项（用逗号、分号或换行分隔），请分别解析每个事项
        7. 只返回 JSON，不要有其他文字
        """
        
        let requestBody: [String: Any] = [
            "model": settings.openAIModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    // MARK: - 响应解析
    
    /// 解析 API 响应
    private func parseResponse(_ data: Data, originalText: String) throws -> [ParsedItem] {
        // 解析外层响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ParserError.parseFailure("无法解析 API 响应")
        }
        
        // 解析内容中的 JSON
        guard let contentData = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw ParserError.parseFailure("无法解析返回的 JSON 内容")
        }
        
        // 提取事项数组
        guard let items = parsed["items"] as? [[String: Any]] else {
            throw ParserError.parseFailure("响应格式错误：缺少 items 数组")
        }
        
        var results: [ParsedItem] = []
        
        for itemData in items {
            if let item = parseSingleItem(itemData, originalText: originalText) {
                results.append(item)
            }
        }
        
        return results
    }
    
    /// 解析单个事项数据
    /// - Parameters:
    ///   - itemData: 事项 JSON 数据
    ///   - originalText: 原始输入文本
    /// - Returns: 解析后的事项
    private func parseSingleItem(_ itemData: [String: Any], originalText: String) -> ParsedItem? {
        // 提取字段
        let typeStr = itemData["type"] as? String ?? "reminder"
        let type: ItemType = typeStr == "calendar" ? .calendar : .reminder
        
        let title = itemData["title"] as? String ?? originalText
        let notes = itemData["notes"] as? String
        
        // 解析日期
        let dueDate = parseISODate(itemData["dueDate"] as? String)
        let endDate = parseISODate(itemData["endDate"] as? String)
        
        let isAllDay = itemData["isAllDay"] as? Bool ?? true
        let priority = itemData["priority"] as? Int ?? 0
        
        // 解析重复周期
        let recurrenceStr = itemData["recurrence"] as? String ?? "none"
        let recurrence = parseRecurrence(recurrenceStr)
        
        let confidence = itemData["confidence"] as? Double ?? 0.8
        
        return ParsedItem(
            type: type,
            title: title,
            notes: notes,
            dueDate: dueDate,
            endDate: endDate,
            isAllDay: isAllDay,
            priorityValue: priority,
            recurrence: recurrence,
            confidence: confidence,
            originalText: originalText
        )
    }
    
    /// 解析 ISO 8601 日期
    private func parseISODate(_ dateStr: String?) -> Date? {
        guard let dateStr = dateStr else { return nil }
        
        // 尝试标准 ISO 8601 格式（带时区和小数秒）
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        // 尝试标准 ISO 8601 格式（带时区，不带小数秒）
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        // 尝试不带时区的日期时间格式 (如 "2026-01-21T10:00:00")
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateTimeFormatter.timeZone = TimeZone.current
        if let date = dateTimeFormatter.date(from: dateStr) {
            return date
        }
        
        // 尝试只有日期的格式 (如 "2026-01-21")
        isoFormatter.formatOptions = [.withFullDate]
        return isoFormatter.date(from: dateStr)
    }
    
    /// 解析重复周期字符串
    private func parseRecurrence(_ str: String) -> RecurrenceRule {
        switch str.lowercased() {
        case "daily":
            return .daily
        case "weekly":
            return .weekly
        case "biweekly":
            return .biweekly
        case "monthly":
            return .monthly
        case "yearly":
            return .yearly
        default:
            return .none
        }
    }
}
