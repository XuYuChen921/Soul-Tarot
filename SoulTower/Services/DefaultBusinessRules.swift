import Foundation

enum DefaultBusinessRules {
    static let policyVersion = "RULE-2026-08-12"
    static let minimumBufferMinutes = 15
    static let lateRescheduleFeeCents = 20_000
    static let expeditedFeeCents = 20_000
    static let reminderOffsets: [TimeInterval] = [24 * 60 * 60, 60 * 60]

    static let servicePolicySummary = """
    预约后不可退单，可更改时间；改期请至少提前 24 小时提出，逾期默认记录 200 元调整费。有空位时可申请加急，默认加急费 200 元。咨询须由本人进行。请保持清醒、室内安静、网络畅通；不在醉酒或意识不清状态下咨询。命运生死、生育性别、博彩投资及股票炒卖类问题不作答；孕妇、重症患者等特殊情况不提供咨询。具体以当前《咨询须知与流程》为准。
    """

    static let projectOrderPolicySummary = """
    本订单属于心理成长配套项目，不替代医疗、法律或投资意见。客户确认服务项目、服务对象、约定总价和交付范围后再付款；付款并开始服务后原则上不可退单。需要变更服务对象、范围、面积或交付内容时，应由双方另行确认费用和时间。涉及未成年人起名、改名的订单必须由监护人提起，本订单不创建未成年人心理成长咨询。资料当前仅在本地设备处理和保存，具体以当前订单记录与双方微信确认内容为准。
    """

    static let packageAfterSalePolicySummary = """
    套餐预约取消时必须由咨询师明确选择“返还 1 次”或“不返还次数”，系统不自动替咨询师决定。返还不会删除原核销记录，而是在原记录上保留返还时间与原因。每个套餐默认只允许人工延期 1 次、最多 30 天，并必须填写原因；延期前后日期永久留痕。服务范围、价格、对象、排期和订单状态变化通过订单变更记录留痕，通用变更记录不会自动改写原订单价格或历史收付款。
    """

    static let consultationArchivePolicySummary = """
    每次咨询资料必须关联预约，分别核对录音、牌阵照片、本地 AI 和长期保存同意。录音、照片和转写文件导入时生成 SHA-256 完整性指纹；录音只使用设备本机离线语音识别转写，不允许降级到云端识别。AI 只生成草稿，正式摘要必须人工批准并按版本永久保留。存在录音时必须人工确认已发送给客户，满足同意、转写、正式摘要和交付条件后才能锁定归档；重新打开归档也必须留痕。
    """

    static let retentionNotice = """
    为便于后续复访、减少重复叙述，并提供历史资料查询，在你明确同意的前提下，心塔拟长期保存咨询录音、牌阵照片、文字转写和经人工确认的正式摘要。资料当前仅保存在本地加密设备及加密备份中，不上传云端 AI，不用于广告或公开案例。长期保存不代表不可删除，你仍可提出查阅、复制、更正、撤回同意或删除申请。
    """

    static let recordingConsentNotice = """
    为完整记录本次服务内容、便于咨询后向你交付录音并支持后续复访，本次咨询拟进行全程录音。录音仅用于本人的资料交付、咨询衔接、复盘和依法处理服务争议，不用于公开传播或无关用途。请在理解录音目的后明确选择是否同意。
    """

    static let localAIConsentNotice = """
    为减少人工整理时间，本次咨询的录音转写或文字记录可由咨询师本地设备上的 AI 模型进行结构化整理。当前处理不上传云端 AI；AI 只生成草稿，必须经咨询师人工核对后才能成为正式摘要。你可以单独选择是否同意本地 AI 处理。
    """

    static let photoConsentNotice = """
    为记录本次咨询使用的牌卡和牌阵，咨询师可能拍摄仅包含牌卡内容的照片。照片不应包含客户面部、聊天窗口或其他无关个人信息，仅用于本次资料归档、复访和经同意的长期保存或限期保留。
    """

    static func isAdult(birthDate: Date?, reference: Date = .now) -> Bool {
        guard let birthDate else { return true }
        guard let threshold = Calendar.current.date(byAdding: .year, value: -18, to: reference) else { return false }
        return birthDate <= threshold
    }

    static func isWithinConsultationHours(start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        let endMinutes = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
        let morning = startMinutes >= 10 * 60 && endMinutes <= 12 * 60
        let evening = startMinutes >= 16 * 60 && endMinutes <= 20 * 60
        return calendar.isDate(start, inSameDayAs: end) && (morning || evening)
    }

    static func hasConflict(
        start: Date,
        end: Date,
        appointments: [Appointment],
        excluding appointmentID: UUID? = nil
    ) -> Bool {
        let buffer = TimeInterval(minimumBufferMinutes * 60)
        let blockedStart = start.addingTimeInterval(-buffer)
        let blockedEnd = end.addingTimeInterval(buffer)

        return appointments.contains { appointment in
            guard appointment.id != appointmentID else { return false }
            guard appointment.status != .cancelled, appointment.status != .rescheduled else { return false }
            return appointment.startAt < blockedEnd && appointment.endAt > blockedStart
        }
    }
}
