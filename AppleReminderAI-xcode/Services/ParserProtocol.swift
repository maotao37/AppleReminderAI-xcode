//
//  ParserProtocol.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  解析器协议定义
//

import Foundation

/// 解析错误类型
enum ParserError: Error, LocalizedError {
    case emptyInput                     // 输入为空
    case parseFailure(String)           // 解析失败
    case networkError(Error)            // 网络错误
    case invalidAPIKey                  // API Key 无效
    case rateLimitExceeded              // 超出速率限制
    case unknownError(Error)            // 未知错误
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "请输入要解析的内容"
        case .parseFailure(let message):
            return "解析失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "API Key 无效，请检查设置"
        case .rateLimitExceeded:
            return "请求过于频繁，请稍后再试"
        case .unknownError(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

/// 解析器协议
/// 所有解析器实现都必须遵循此协议
protocol ItemParser {
    /// 解析自然语言输入
    /// - Parameter input: 用户输入的自然语言文本
    /// - Returns: 解析后的事项数组，支持从一段文本中解析出多个事项
    func parse(_ input: String) async throws -> [ParsedItem]
    
    /// 解析器名称
    var name: String { get }
    
    /// 解析器描述
    var description: String { get }
    
    /// 是否需要网络连接
    var requiresNetwork: Bool { get }
}

/// 解析器工厂
/// 根据设置创建对应的解析器实例
class ParserFactory {
    /// 根据当前设置获取解析器
    static func createParser(for mode: ParserMode) -> ItemParser {
        switch mode {
        case .native:
            return NLPParser()
        case .openAI:
            return OpenAIParser()
        }
    }
    
    /// 使用当前设置创建默认解析器
    static func createDefaultParser() -> ItemParser {
        return createParser(for: AppSettings.shared.parserMode)
    }
}
