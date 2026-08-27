import Foundation

enum BrandGrowthAIError: LocalizedError {
    case noActiveProfile
    case invalidJSON
    case parseFail(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProfile:
            return "请先在“品牌设置”中建立并启用品牌档案。"
        case .invalidJSON:
            return "AI 输出格式不可识别，请改为先人工编辑再提交。"
        case .parseFail(let detail):
            return detail
        }
    }
}

struct BrandDraftPayload {
    let title: String
    let subtitle: String
    let opening: String
    let body: String
    let actionPrompt: String
    let imageSuggestion: String
    let searchTitles: [String]
    let resonanceTitles: [String]
    let keywords: [String]
    let hashtags: [String]
    let riskWarnings: [String]

    var previewTitle: String { (searchTitles + resonanceTitles + [title]).first ?? title }
}

struct BrandDraftGenerationBundle {
    let wechat: BrandDraftPayload
    let xiaohongshu: BrandDraftPayload
}

enum BrandGrowthAIService {
    static func generateDraftBundle(
        for topic: BrandContentTopic,
        profile: BrandProfile,
        baseURL: String,
        modelName: String
    ) async throws -> BrandDraftGenerationBundle {
        let wechat = try await generate(channel: .wechatMoments, topic: topic, profile: profile, baseURL: baseURL, modelName: modelName)
        let xiaohongshu = try await generate(channel: .xiaohongshu, topic: topic, profile: profile, baseURL: baseURL, modelName: modelName)
        return BrandDraftGenerationBundle(wechat: wechat, xiaohongshu: xiaohongshu)
    }

    static func generate(
        channel: BrandDistributionChannel,
        topic: BrandContentTopic,
        profile: BrandProfile,
        baseURL: String,
        modelName: String
    ) async throws -> BrandDraftPayload {
        let inputRisks = BrandGrowthRiskService.evaluate(
            title: topic.title,
            content: topic.rawIdea,
            profile: profile
        )
        guard inputRisks.isEmpty else { throw BrandGrowthWorkflowError.blockingRisk(inputRisks) }
        let response = try await LocalAIService().generateStructuredJSON(
            prompt: channelPrompt(channel: channel, topic: topic, profile: profile),
            baseURL: baseURL,
            model: modelName
        )
        let payload = try parsePayload(from: response, channel: channel)
        return withRiskChecked(payload: payload, topic: topic, profile: profile)
    }

    private static func channelPrompt(
        channel: BrandDistributionChannel,
        topic: BrandContentTopic,
        profile: BrandProfile
    ) -> String {
        let base = """
        你是“心塔”品牌增长模块的合规文案助手，只允许使用公开和品牌素材，禁止引导确定性疗法、投资、彩票、性别、命运生死承诺。

        当前品牌定位：\(profile.brandName) · \(profile.oneLinePositioning)
        目标人群：\(profile.targetAudience)
        品牌语气：\(profile.tone)
        常用表达：\(profile.commonWords)
        禁用表达：\(profile.forbiddenWords)

        选题标题：\(topic.title)
        原始观点：\(topic.rawIdea)
        目标人群：\(topic.targetAudience)
        内容支柱：\(topic.pillar)
        目标：\(topic.goal.rawValue)
        行动提示：\(topic.actionHint)

        只输出 JSON，不要 markdown。
        """

        switch channel {
        case .wechatMoments:
            return base + """
            生成微信朋友圈版本，返回 JSON：
            {
              \"title\": "简短标题",
              \"subtitle\": "副标题，可选",
              \"opening\": "开头",
              \"body\": "正文，风格真实、非模板化",
              \"actionPrompt\": "结尾行动提示",
              \"imageSuggestion\": "配图建议",
              \"searchTitles\": [],
              \"resonanceTitles\": [],
              \"keywords\": ["关键字"],
              \"hashtags\": ["#tag"],
              \"riskWarnings\": ["待人工复核风险"]
            }
            """
        case .xiaohongshu:
            return base + """
            生成小红书版本，返回 JSON：
            {
              \"title\": "建议主标题",
              \"subtitle\": "副标题",
              \"opening\": "开头",
              \"body\": "正文",
              \"actionPrompt\": "引导评论/收藏/咨询",
              \"imageSuggestion\": "封面与配图建议",
              \"searchTitles\": ["搜索型标题1","搜索型标题2"],
              \"resonanceTitles\": ["共鸣型标题1","共鸣型标题2"],
              \"keywords\": ["关键词"],
              \"hashtags\": ["#相关标签"],
              \"riskWarnings\": ["待人工复核风险"]
            }
            """
        }
    }

    private static func parsePayload(from text: String, channel: BrandDistributionChannel) throws -> BrandDraftPayload {
        struct RawPayload: Decodable {
            let title: String
            let subtitle: String?
            let opening: String
            let body: String
            let actionPrompt: String
            let imageSuggestion: String?
            let searchTitles: [String]?
            let resonanceTitles: [String]?
            let keywords: [String]?
            let hashtags: [String]?
            let riskWarnings: [String]?
        }

        let extracted = extractJSON(from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extracted.isEmpty else { throw BrandGrowthAIError.invalidJSON }
        guard let data = extracted.data(using: .utf8) else { throw BrandGrowthAIError.parseFail("AI 返回无法转成 UTF-8 数据。") }

        do {
            let parsed = try JSONDecoder().decode(RawPayload.self, from: data)
            let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let opening = parsed.opening.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let actionPrompt = parsed.actionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageSuggestion = parsed.imageSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return BrandDraftPayload(
                title: title,
                subtitle: parsed.subtitle ?? "",
                opening: opening,
                body: body,
                actionPrompt: actionPrompt,
                imageSuggestion: imageSuggestion,
                searchTitles: parsed.searchTitles ?? [],
                resonanceTitles: parsed.resonanceTitles ?? [],
                keywords: parsed.keywords ?? [],
                hashtags: parsed.hashtags ?? [],
                riskWarnings: parsed.riskWarnings ?? []
            )
        } catch {
            if channel == .wechatMoments {
                return BrandDraftPayload(
                    title: "\(topicTitleHint(from: extracted))",
                    subtitle: "",
                    opening: "",
                    body: extracted,
                    actionPrompt: "",
                    imageSuggestion: "",
                    searchTitles: [],
                    resonanceTitles: [],
                    keywords: [],
                    hashtags: [],
                    riskWarnings: []
                )
            }
            throw BrandGrowthAIError.parseFail("AI 输出 JSON 解析失败：\(error.localizedDescription)")
        }
    }

    private static func withRiskChecked(payload: BrandDraftPayload, topic: BrandContentTopic, profile: BrandProfile) -> BrandDraftPayload {
        var result = payload
        var risks = Set(payload.riskWarnings)
        let allText = [payload.title, payload.subtitle, payload.opening, payload.body, payload.actionPrompt, payload.imageSuggestion].joined(separator: "\n")

        let forbidden: [String] = [
            "包治", "必胜", "必然", "保你", "命运", "投资", "生死", "治疗", "保证", "断言", "绝对", "立刻", "马上", "稳赢", "偏方", "偏方", "必中", "一定会"
        ]

        if forbidden.contains(where: { allText.contains($0) }) {
            risks.insert("高风险：出现确定性疗法/结果承诺或过度承诺词。")
        }
        if allText.containsRegex("\\d{11}") {
            risks.insert("高风险：疑似包含完整电话/联系方式信息。")
        }
        if topic.sensitivity.contains("客户") && allText.contains("真实姓名") {
            risks.insert("高风险：疑似包含个人身份指向信息。")
        }

        for forbiddenWord in profile.forbiddenWordsList where allText.contains(forbiddenWord) {
            risks.insert("高风险：草稿中出现品牌禁用表达“\(forbiddenWord)”。")
        }

        let sortedRisk = risks.filter { !$0.isEmpty }.sorted()
        result = BrandDraftPayload(
            title: result.title,
            subtitle: result.subtitle,
            opening: result.opening,
            body: result.body,
            actionPrompt: result.actionPrompt,
            imageSuggestion: result.imageSuggestion,
            searchTitles: result.searchTitles,
            resonanceTitles: result.resonanceTitles,
            keywords: result.keywords,
            hashtags: result.hashtags,
            riskWarnings: sortedRisk
        )
        return result
    }

    private static func topicTitleHint(from value: String) -> String {
        let fallback = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(fallback.prefix(18)).isEmpty ? "选题草稿" : String(fallback.prefix(18))
    }

    private static func extractJSON(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return text }
        return String(text[start...end])
    }
}

private extension String {
    func containsRegex(_ regex: String) -> Bool {
        self.range(of: regex, options: .regularExpression) != nil
    }
}
