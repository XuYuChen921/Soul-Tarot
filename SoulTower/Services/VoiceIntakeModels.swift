import Foundation

enum VoiceIntakeTemplate {
    static let requiredItems = [
        "客户称呼和阳历出生日期",
        "客户来源（例如熟人介绍）",
        "要预约的服务项目",
        "预约完整年月日、上午/下午和开始时间，以及使用 Mac 还是服务 iPhone",
        "付款状态",
        "是否已同意当前服务规则",
        "是否同意录音、牌阵照片、本地 AI 处理、长期保存（四项分别说）"
    ]

    static let example = """
    新客户称呼小林，微信昵称林林，阳历出生日期 1993 年 5 月 18 日，来源是朋友张姐介绍。预约新客塔罗心理咨询，2026 年 8 月 20 日下午 4 点，使用 Mac 视频，已经付款。客户已同意当前服务规则；同意录音；同意拍摄牌阵照片；同意本地 AI 处理；同意长期保存。备注是第一次咨询，主要想梳理近期关系压力。
    """
}

enum VoiceIntakeGroundingService {
    static func ground(_ aiDraft: VoiceIntakeDraft, transcript: String, now: Date = .now) -> VoiceIntakeDraft {
        var result = aiDraft
        result.displayName = labeledText(pattern: #"(?:新客户)?客户?称呼(?:是|为)?\s*([^，,。；;\n]{1,24})"#, in: transcript)
        result.wechatNickname = labeledText(pattern: #"微信昵称(?:是|为)?\s*([^，,。；;\n]{1,32})"#, in: transcript)
        result.phone = labeledPhone(in: transcript)
        result.source = labeledText(pattern: #"来源(?:是|为)?\s*([^，,。；;\n]{1,40})"#, in: transcript)
        result.birthDateText = explicitBirthDate(in: transcript) ?? ""
        result.serviceName = groundedText(aiDraft.serviceName, in: transcript)
        result.appointmentStartText = explicitAppointmentStart(in: transcript, now: now) ?? ""
        result.videoDevice = explicitVideoDevice(in: transcript)
        result.paymentStatus = explicitPaymentStatus(in: transcript)
        result.policyConsent = explicitConsent(in: transcript, keywords: ["服务规则", "咨询规则", "当前规则"])
        result.recordingConsent = explicitConsent(in: transcript, keywords: ["录音"])
        result.photoConsent = explicitConsent(in: transcript, keywords: ["牌阵照片", "拍照", "照片"])
        result.localAIConsent = explicitConsent(in: transcript, keywords: ["本地ai", "本地 ai", "ai处理", "ai 处理"])
        result.retentionConsent = explicitConsent(in: transcript, keywords: ["长期保存", "永久保存", "永久保留"])
        return result
    }

    private static func groundedText(_ value: String, in transcript: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              transcript.range(of: clean, options: [.caseInsensitive, .diacriticInsensitive]) != nil else { return "" }
        return clean
    }

    private static func labeledText(pattern: String, in transcript: String) -> String {
        guard let groups = firstMatch(pattern: pattern, in: transcript), groups.count >= 2 else { return "" }
        return groups[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func labeledPhone(in transcript: String) -> String {
        let value = labeledText(pattern: #"(?:手机号|手机号码|手机|电话)(?:是|为)?\s*([0-9][0-9\s-]{6,20})"#, in: transcript)
        let digits = value.filter(\.isNumber)
        return digits.count >= 7 ? digits : ""
    }

    private static func explicitBirthDate(in transcript: String) -> String? {
        let pattern = #"(?:阳历)?出生日期?[^0-9]{0,8}(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?"#
        guard let groups = firstMatch(pattern: pattern, in: transcript), groups.count == 4,
              let year = Int(groups[1]), let month = Int(groups[2]), let day = Int(groups[3]),
              validDate(year: year, month: month, day: day) != nil else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func explicitAppointmentStart(in transcript: String, now: Date) -> String? {
        let nsText = transcript as NSString
        let markerRange = nsText.range(of: "预约", options: .backwards)
        guard markerRange.location != NSNotFound else { return nil }
        let searchRange = NSRange(location: markerRange.location, length: nsText.length - markerRange.location)
        let datePattern = #"(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern),
              let dateMatch = dateRegex.firstMatch(in: transcript, range: searchRange),
              let year = integerGroup(1, match: dateMatch, text: nsText),
              let month = integerGroup(2, match: dateMatch, text: nsText),
              let day = integerGroup(3, match: dateMatch, text: nsText) else { return nil }

        let timeSearchStart = NSMaxRange(dateMatch.range)
        let timeSearchLength = min(48, nsText.length - timeSearchStart)
        guard timeSearchLength > 0 else { return nil }
        let timePattern = #"(上午|下午|晚上|中午)?\s*(\d{1,2})\s*[点时](?:(\d{1,2})\s*分|半)?"#
        guard let timeRegex = try? NSRegularExpression(pattern: timePattern),
              let timeMatch = timeRegex.firstMatch(in: transcript, range: NSRange(location: timeSearchStart, length: timeSearchLength)),
              var hour = integerGroup(2, match: timeMatch, text: nsText) else { return nil }

        let meridiem = stringGroup(1, match: timeMatch, text: nsText)
        if ["下午", "晚上"].contains(meridiem), hour < 12 { hour += 12 }
        if meridiem == "中午", hour < 11 { hour += 12 }
        if meridiem.isEmpty, hour <= 12 { return nil }
        let minute = integerGroup(3, match: timeMatch, text: nsText) ?? (nsText.substring(with: timeMatch.range).contains("半") ? 30 : 0)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func explicitVideoDevice(in transcript: String) -> VideoDevice? {
        let lower = transcript.lowercased()
        if lower.contains("服务 iphone") || lower.contains("服务iphone") || lower.contains("用iphone") || lower.contains("用 iphone") { return .iPhone }
        if lower.contains("mac") { return .mac }
        if transcript.contains("设备待定") || transcript.contains("待确定设备") { return .undecided }
        return nil
    }

    private static func explicitPaymentStatus(in transcript: String) -> PaymentStatus? {
        if containsAny(transcript, ["未付款", "没付款", "还没付款", "尚未付款"]) { return .unpaid }
        if containsAny(transcript, ["部分付款", "付了一部分"]) { return .partial }
        if containsAny(transcript, ["余额抵扣", "用余额"]) { return .balance }
        if containsAny(transcript, ["已退款", "已经退款"]) { return .refunded }
        if containsAny(transcript, ["已付款", "已经付款", "付过款", "已付清"]) { return .paid }
        return nil
    }

    private static func explicitConsent(in transcript: String, keywords: [String]) -> ExplicitConsentChoice {
        let segments = transcript.components(separatedBy: CharacterSet(charactersIn: "，,。；;！!？?\n"))
        guard let segment = segments.last(where: { value in
            let lower = value.lowercased()
            return keywords.contains { lower.contains($0.lowercased()) }
        }) else { return .unknown }
        if containsAny(segment, ["不同意", "未同意", "不允许", "不接受", "拒绝", "不同意愿"]) { return .declined }
        if containsAny(segment, ["同意", "允许", "接受", "可以"]) { return .accepted }
        return .unknown
    }

    private static func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let nsText = text as NSString
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : nsText.substring(with: range)
        }
    }

    private static func integerGroup(_ index: Int, match: NSTextCheckingResult, text: NSString) -> Int? {
        let value = stringGroup(index, match: match, text: text)
        return Int(value)
    }

    private static func stringGroup(_ index: Int, match: NSTextCheckingResult, text: NSString) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : text.substring(with: range)
    }

    private static func validDate(year: Int, month: Int, day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }
}

enum ExplicitConsentChoice: String, CaseIterable, Identifiable {
    case unknown = "未说明"
    case accepted = "同意"
    case declined = "不同意"

    var id: String { rawValue }

    init(_ value: Bool?) {
        switch value {
        case true: self = .accepted
        case false: self = .declined
        case nil: self = .unknown
        }
    }

    var boolValue: Bool? {
        switch self {
        case .accepted: return true
        case .declined: return false
        case .unknown: return nil
        }
    }
}

struct VoiceIntakeDraft: Equatable {
    var displayName = ""
    var wechatNickname = ""
    var phone = ""
    var source = "熟人介绍"
    var birthDateText = ""
    var serviceName = ""
    var appointmentStartText = ""
    var videoDevice: VideoDevice?
    var paymentStatus: PaymentStatus?
    var policyConsent: ExplicitConsentChoice = .unknown
    var recordingConsent: ExplicitConsentChoice = .unknown
    var photoConsent: ExplicitConsentChoice = .unknown
    var localAIConsent: ExplicitConsentChoice = .unknown
    var retentionConsent: ExplicitConsentChoice = .unknown
    var archiveSummary = ""
    var modelReportedMissingFields: [String] = []

    static func parseAIResponse(_ response: String) throws -> VoiceIntakeDraft {
        guard let open = response.firstIndex(of: "{"), let close = response.lastIndex(of: "}"), open <= close else {
            throw LocalAIError.invalidResponse
        }
        let json = String(response[open...close])
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalAIError.invalidResponse
        }

        func string(_ key: String) -> String {
            guard let value = object[key], !(value is NSNull) else { return "" }
            return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        func bool(_ key: String) -> Bool? {
            guard let value = object[key], !(value is NSNull) else { return nil }
            if let number = value as? NSNumber { return number.boolValue }
            if let text = value as? String {
                switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "同意", "是", "已同意": return true
                case "false", "no", "不同意", "否", "拒绝": return false
                default: return nil
                }
            }
            return nil
        }
        func strings(_ key: String) -> [String] {
            (object[key] as? [Any])?.compactMap { $0 as? String } ?? []
        }

        let deviceText = string("videoDevice")
        let paymentText = string("paymentStatus")
        return VoiceIntakeDraft(
            displayName: string("displayName"),
            wechatNickname: string("wechatNickname"),
            phone: string("phone"),
            source: string("source").isEmpty ? "熟人介绍" : string("source"),
            birthDateText: string("birthDate"),
            serviceName: string("serviceName"),
            appointmentStartText: string("appointmentStart"),
            videoDevice: VideoDevice.allCases.first { $0.rawValue == deviceText },
            paymentStatus: PaymentStatus.allCases.first { $0.rawValue == paymentText },
            policyConsent: ExplicitConsentChoice(bool("policyAccepted")),
            recordingConsent: ExplicitConsentChoice(bool("recordingAccepted")),
            photoConsent: ExplicitConsentChoice(bool("photoAccepted")),
            localAIConsent: ExplicitConsentChoice(bool("localAIAccepted")),
            retentionConsent: ExplicitConsentChoice(bool("retentionAccepted")),
            archiveSummary: string("archiveSummary"),
            modelReportedMissingFields: strings("missingFields")
        )
    }
}

enum VoiceIntakeDateParser {
    static func birthDate(_ text: String) -> Date? {
        formatter("yyyy-MM-dd").date(from: normalized(text))
    }

    static func appointmentStart(_ text: String) -> Date? {
        let clean = normalized(text)
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm", "yyyy/MM/dd HH:mm"] {
            if let date = formatter(format).date(from: clean) { return date }
        }
        return nil
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
