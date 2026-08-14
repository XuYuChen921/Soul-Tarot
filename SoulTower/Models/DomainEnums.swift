import Foundation
import SwiftUI

enum AppointmentStatus: String, CaseIterable, Codable, Identifiable {
    case pendingRules = "待规则同意"
    case pendingPayment = "待付款"
    case confirmed = "已预约"
    case inProgress = "进行中"
    case completed = "已完成"
    case rescheduled = "已改期"
    case cancelled = "已取消"
    case noShow = "爽约"

    var id: String { rawValue }
}

enum PaymentStatus: String, CaseIterable, Codable, Identifiable, Hashable {
    case unpaid = "未付款"
    case paid = "已付款"
    case partial = "部分付款"
    case balance = "余额抵扣"
    case refunded = "已退款"
    case entitlement = "套餐权益"

    var id: String { rawValue }
}

enum ServiceOrderStatus: String, CaseIterable, Codable, Identifiable, Hashable {
    case pendingPayment = "待付款"
    case active = "进行中"
    case completed = "已完成"
    case expired = "已到期"
    case cancelled = "已取消"

    var id: String { rawValue }
}

enum ServiceOrderChangeKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case expirationExtended = "套餐延期"
    case entitlementReturned = "次数返还"
    case entitlementKept = "取消未返还"
    case scopeChanged = "服务范围变更"
    case scheduleChanged = "交付时间变更"
    case priceChanged = "金额或数量变更"
    case subjectChanged = "服务对象变更"
    case statusChanged = "订单状态变更"
    case other = "其他变更"

    var id: String { rawValue }
}

enum PaymentTransactionKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case servicePayment = "咨询费收款"
    case rushFee = "加急费"
    case rescheduleFee = "改期费"
    case refund = "退款"
    case balanceOffset = "余额抵扣"
    case otherIncome = "其他收款"

    var id: String { rawValue }

    var isIncome: Bool {
        self != .refund && self != .balanceOffset
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable, Hashable {
    case wechat = "微信收款"
    case bankTransfer = "银行转账"
    case cash = "现金"
    case balance = "账户余额"
    case other = "其他"
    case legacy = "旧版迁移"

    var id: String { rawValue }
}

enum VideoDevice: String, CaseIterable, Codable, Identifiable {
    case undecided = "待确定"
    case mac = "Mac"
    case iPhone = "服务 iPhone"

    var id: String { rawValue }
}

enum PricingMode: String, CaseIterable, Codable, Identifiable {
    case fixed = "固定价"
    case startingAt = "起价"
    case perSquareMeter = "按平方米"

    var id: String { rawValue }
}

enum DeliveryType: String, CaseIterable, Codable, Identifiable {
    case video = "视频咨询"
    case nonVideo = "非视频"
    case project = "项目制"

    var id: String { rawValue }
}

enum ProductKind: String, CaseIterable, Codable, Identifiable {
    case singleConsultation = "单次服务"
    case package = "次数套餐"
    case project = "长期项目"

    var id: String { rawValue }
}

enum EntitlementRedemptionState: String, CaseIterable, Codable, Identifiable {
    case reserved = "已占用"
    case consumed = "已核销"

    var id: String { rawValue }
}

enum ProjectStage: String, CaseIterable, Codable, Identifiable {
    case awaitingMaterials = "资料待齐"
    case quoted = "已报价"
    case awaitingDeposit = "待首款"
    case inProgress = "执行中"
    case awaitingConfirmation = "待客户确认"
    case awaitingBalance = "待尾款"
    case delivered = "已交付"
    case archived = "已归档"

    var id: String { rawValue }
}

enum ConsentType: String, CaseIterable, Codable, Identifiable {
    case servicePolicy = "服务规则"
    case recording = "咨询录音"
    case localAI = "本地 AI 处理"
    case longTermRetention = "长期保存"
    case photo = "牌阵照片"

    var id: String { rawValue }
}

enum MediaKind: String, CaseIterable, Codable, Identifiable {
    case audio = "录音"
    case image = "照片"
    case transcript = "转写文件"
    case document = "其他资料"

    var id: String { rawValue }
}

enum AIRecordStatus: String, CaseIterable, Codable, Identifiable {
    case noTranscript = "待转写"
    case ready = "待整理"
    case generating = "整理中"
    case draft = "待校对"
    case approved = "已批准"
    case failed = "处理失败"

    var id: String { rawValue }
}

enum TranscriptSource: String, CaseIterable, Codable, Identifiable {
    case manual = "人工录入"
    case importedFile = "导入转写文件"
    case onDeviceAudio = "本机录音转写"

    var id: String { rawValue }
}

enum ConsultationArchiveStatus: String, CaseIterable, Codable, Identifiable {
    case collecting = "资料收集中"
    case organizing = "待整理"
    case review = "待确认归档"
    case archived = "已归档"

    var id: String { rawValue }
}

enum ConsultationActivityKind: String, CaseIterable, Codable, Identifiable {
    case recordCreated = "建立记录"
    case mediaImported = "导入资料"
    case transcriptSaved = "保存转写"
    case localTranscription = "本机转写"
    case aiDraftGenerated = "AI 草稿"
    case summaryDraftSaved = "保存摘要草稿"
    case formalSummaryApproved = "批准摘要"
    case recordingDelivered = "交付录音"
    case archived = "完成归档"
    case reopened = "重新打开"

    var id: String { rawValue }
}

extension AppointmentStatus {
    var color: Color {
        switch self {
        case .confirmed: return .teal
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled, .noShow: return .red
        case .rescheduled: return .purple
        case .pendingRules, .pendingPayment: return .yellow
        }
    }
}

extension AIRecordStatus {
    var color: Color {
        switch self {
        case .noTranscript: return .secondary
        case .ready: return .blue
        case .generating: return .orange
        case .draft: return .purple
        case .approved: return .green
        case .failed: return .red
        }
    }
}

extension ConsultationArchiveStatus {
    var color: Color {
        switch self {
        case .collecting: return .orange
        case .organizing: return .blue
        case .review: return .purple
        case .archived: return .green
        }
    }
}

extension Int {
    var yuanText: String {
        let amount = Decimal(self) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = self % 100 == 0 ? 0 : 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "¥\(self / 100)"
    }
}

extension Date {
    var dayStart: Date { Calendar.current.startOfDay(for: self) }

    var dayEnd: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? self
    }
}
