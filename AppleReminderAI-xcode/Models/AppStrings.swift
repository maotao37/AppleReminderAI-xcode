//
//  AppStrings.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  用户可见文案集中管理：后续做本地化时只需替换此文件取值方式
//

import Foundation

enum L10n {
    // MARK: - 通用
    enum Common {
        static let settings = "设置"
        static let done = "完成"
        static let cancel = "取消"
        static let remove = "移除此事项"
        static let expandEdit = "展开编辑"
        static let collapseEdit = "收起详情"
        static let optional = "可选"
        static let notSet = "未设置"
        static let createThisItem = "创建此事项"
    }

    // MARK: - 优先级显示
    enum PriorityDisplay {
        static let none = "无"
        static let low = "低"
        static let medium = "中"
        static let high = "高"
    }

    // MARK: - 主界面
    enum Main {
        static let title = "苹果提醒事项 AI"
        static let subtitle = "输入内容，智能同步到日历和提醒事项"
        static let inputPlaceholder = "例如：每周一提醒我提交周报"
        static let aiParse = "AI 解析"
        static let cancelParse = "取消解析"
        static let parsing = "正在解析内容..."
        static let cancel = "取消"

        static func parseResultCount(_ count: Int) -> String {
            "解析结果（\(count) 项）"
        }
    }

    // MARK: - 解析结果编辑
    enum ParsedList {
        static let type = "类型"
        static let titleField = "标题"
        static let titlePlaceholder = "输入标题"
        static let startTime = "开始时间"
        static let reminderTime = "提醒时间"
        static let endTime = "结束时间"
        static let allDay = "全天"
        static let recurrence = "重复周期"
        static let alert = "提醒"
        static let alertOnTime = "准时"
        static let priority = "优先级"
        static let repeatOn = "重复于"
        static let monthlyRule = "每月规则"
        static let monthlyPlain = "仅每月"
        static let monthlyByDate = "按日期"
        static let monthlyByNthWeekday = "按第N个星期"
        static let monthlyDaySuffix = "日"
        static let nthFirst = "第一个"
        static let nthSecond = "第二个"
        static let nthThird = "第三个"
        static let nthFourth = "第四个"
        static let nthLast = "最后一个"
        static let yearlyOn = "每年于"

        static func monthlyByDateNth(_ day: Int) -> String {
            "每月 \(day) 日"
        }

        static func monthNumber(_ month: Int) -> String {
            "\(month) 月"
        }

        static func dayNumber(_ day: Int) -> String {
            "\(day) 日"
        }
        static let monthSuffix = "月"
        static let recurrenceEndToggle = "设置重复截止日期"
        static let recurrenceEnd = "截止"
        static let saveToReminderList = "保存至提醒事项列表"
        static let saveToCalendar = "保存至日历"
        static let permissionPendingGroup = "创建时请求权限并使用系统默认分组"
        static let notes = "备注"
        static let calendarNeedsDate = "日历事件需要设置开始日期"
        static let confirmCreatePrefix = "确认创建并同步到苹果"
        static let lowConfidence = "请确认"
        static let createAll = "全部创建"

        static func creatingProgress(_ current: Int, _ total: Int) -> String {
            "创建中 \(current)/\(total)"
        }

        static func interval(_ value: Int) -> String {
            "间隔 \(value)"
        }

        static func minutesEarly(_ value: Int) -> String {
            "提前 \(value) 分钟"
        }

        static let alertEarly1Hour = "提前 1 小时"
        static let alertEarly1Day = "提前 1 天"

        static func confirmCreate(typeName: String) -> String {
            confirmCreatePrefix + typeName
        }
    }

    // MARK: - 星期/序数/月份显示
    enum RecurrenceDisplay {
        static let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        static let weekdayShort = ["一", "二", "三", "四", "五", "六", "日"]

        static func ordinal(_ position: Int) -> String {
            switch position {
            case 1: return "第一个"
            case 2: return "第二个"
            case 3: return "第三个"
            case 4: return "第四个"
            case -1: return "最后一个"
            default: return "第\(position)个"
            }
        }

        static func weekdayName(_ isoWeekday: Int) -> String {
            guard weekdays.indices.contains(isoWeekday - 1) else { return "" }
            return weekdays[isoWeekday - 1]
        }
    }

    // MARK: - 历史记录
    enum History {
        static let title = "最近创建"
        static let clear = "清空记录"
        static let empty = "暂无创建记录"
        static let clearConfirmTitle = "清空所有创建记录？"
        static let undoRecurringTitle = "撤销重复事件？"
        static let undoRecurringAction = "删除此事件及所有未来实例"
        static let undoRecurringMessagePrefix = "“"
        static let undoRecurringMessageSuffix = "”是重复日历事件，撤销将删除该事件及其所有未来重复实例"
        static let retryHelp = "重新编辑并创建"
        static let undoHelp = "撤销创建"
        static let statusUndone = "已撤销"
        static let statusSuccess = "已成功创建"
        static let statusFailed = "创建失败"

        static func undoRecurringMessage(_ title: String) -> String {
            undoRecurringMessagePrefix + title + undoRecurringMessageSuffix
        }
    }

    // MARK: - 设置
    enum Settings {
        static let title = "应用设置"
        static let general = "通用设置"
        static let menuBar = "在状态栏显示"
        static let historyLimit = "历史记录上限"
        static let openAISection = "OpenAI 配置"
        static let apiKeyField = "API Key"
        static let baseURLField = "API Base URL"
        static let modelField = "AI 模型"
        static let notConfiguredWarning = "请检查 API Key 和服务地址；远程地址必须使用 HTTPS"
        static let privacyNote = "AI 解析会将输入内容和现有分组名称发送到所配置的服务端。API Key 存储在系统钥匙串中。"
        static let permissions = "系统权限"
        static let reminderPermission = "提醒事项权限"
        static let calendarPermission = "日历权限"
        static let requestPermission = "去请求"
        static let openSystemSettings = "去设置"
        static let about = "关于"
        static let versionFormat = "版本"

        static func limitOption(_ value: Int) -> String {
            "\(value) 条"
        }
    }

    // MARK: - 应用菜单
    enum App {
        static let showMainWindow = "显示主界面"
        static let openSettings = "设置..."
        static let quit = "退出"
    }

    // MARK: - 解析器描述
    enum Parser {
        static let nativeName = "原生解析器"
        static let nativeDescription = "使用系统内置的自然语言处理，离线可用"
        static let aiName = "AI 解析器"
        static let aiDescription = "使用 OpenAI API 进行智能解析，支持更复杂的自然语言表达"
    }

    // MARK: - 权限状态
    enum Permission {
        static let fullAccess = "完全访问"
        static let writeOnly = "仅写入"
        static let notDetermined = "未确定"
        static let restricted = "受限制"
        static let denied = "已拒绝"
        static let authorized = "已授权"
        static let unknown = "未知"
    }

    // MARK: - 提示消息
    enum Message {
        static let reminderCreated = "提醒事项已创建"
        static let eventCreated = "日历事件已创建"
        static let retryQueued = "已将事项放回待创建列表"
        static let undone = "已撤销创建"
        static let historyLoadFailed = "历史记录加载失败，可能已损坏；新的创建记录会正常保存"
        static let unparseable = "无法解析输入内容，请尝试更具体的描述"

        static func created(_ count: Int) -> String {
            "成功创建 \(count) 个事项"
        }

        static func createPartialResult(success: Int, failure: Int) -> String {
            "创建完成：成功 \(success) 个，失败 \(failure) 个；失败项已保留，可直接重试"
        }

        static func parseFailed(_ reason: String) -> String {
            "解析失败: \(reason)"
        }

        static func undoFailed(_ reason: String) -> String {
            "撤销失败: \(reason)"
        }

        static func requestPermissionFailed(_ reason: String) -> String {
            "请求权限失败: \(reason)"
        }
    }

    // MARK: - 错误信息
    enum Errors {
        static let emptyInput = "请输入要解析的内容"
        static let invalidAPIKey = "API Key 无效，请检查设置"
        static let rateLimitExceeded = "请求过于频繁，请稍后再试"
        static let invalidResponse = "无效的响应"
        static let cannotParseResponse = "无法解析 API 响应"
        static let cannotParseJSON = "无法解析返回的 JSON 内容"
        static let missingItems = "响应格式错误：缺少 items 数组"
        static let httpsRequired = "API URL 必须使用 HTTPS；本机服务可使用 localhost HTTP"
        static let cannotEncodeGroups = "无法编码分组列表"

        static func parseFailure(_ message: String) -> String { "解析失败: \(message)" }
        static func network(_ message: String) -> String { "网络错误: \(message)" }
        static func unknown(_ message: String) -> String { "未知错误: \(message)" }
        static func apiError(_ status: Int, _ body: String) -> String { "API 错误 (\(status)): \(body)" }
    }

    // MARK: - 服务错误
    enum ReminderError {
        static let noAccess = "没有提醒事项访问权限"
        static let listNotFound = "找不到指定的提醒事项列表"
        static let notFound = "找不到指定的提醒事项"
        static let duplicate = "目标列表中已存在标题和时间相同的提醒事项"

        static func saveFailed(_ message: String) -> String { "保存失败: \(message)" }
    }

    enum CalendarError {
        static let noAccess = "没有日历访问权限"
        static let calendarNotFound = "找不到指定的日历"
        static let eventNotFound = "找不到指定的事件"
        static let missingDate = "日历事件必须设置开始日期"
        static let duplicate = "目标日历中已存在标题和时间相同的事件"

        static func saveFailed(_ message: String) -> String { "保存失败: \(message)" }
    }
}
