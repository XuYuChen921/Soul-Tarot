import Foundation

enum BrandMetricImportError: LocalizedError {
    case emptyFile
    case missingColumns([String])
    case invalidRow(Int, String)
    case unmatchedRecord(Int, String)
    case ambiguousRecord(Int, String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "表格为空，未找到可导入的数据。"
        case .missingColumns(let values):
            return "缺少必需列：\(values.joined(separator: "、"))。"
        case .invalidRow(let row, let reason):
            return "第 \(row) 行无法导入：\(reason)"
        case .unmatchedRecord(let row, let identifier):
            return "第 \(row) 行找不到发布记录：\(identifier)"
        case .ambiguousRecord(let row, let identifier):
            return "第 \(row) 行匹配到多条发布记录：\(identifier)"
        }
    }
}

enum BrandMetricImportColumn: String, CaseIterable, Hashable {
    case publishIdentifier
    case collectedAt
    case periodStart
    case periodEnd
    case exposure
    case views
    case likes
    case comments
    case favorites
    case shares
    case profileVisits
    case followers
    case privateMessages
    case missingReasons

    var displayName: String {
        switch self {
        case .publishIdentifier: return "发布记录标识"
        case .collectedAt: return "采集时间"
        case .periodStart: return "覆盖开始"
        case .periodEnd: return "覆盖结束"
        case .exposure: return "曝光"
        case .views: return "阅读/播放"
        case .likes: return "点赞"
        case .comments: return "评论"
        case .favorites: return "收藏"
        case .shares: return "分享"
        case .profileVisits: return "主页访问"
        case .followers: return "新增关注"
        case .privateMessages: return "私信/询盘"
        case .missingReasons: return "缺失说明"
        }
    }

    var aliases: Set<String> {
        switch self {
        case .publishIdentifier: return ["发布记录标识", "发布记录id", "内容id", "内容编号", "链接", "标题", "publishid", "postid"]
        case .collectedAt: return ["采集时间", "更新时间", "collectedat"]
        case .periodStart: return ["覆盖开始", "周期开始", "periodstart"]
        case .periodEnd: return ["覆盖结束", "周期结束", "periodend"]
        case .exposure: return ["曝光", "展现", "exposure", "impressions"]
        case .views: return ["阅读", "播放", "浏览", "views"]
        case .likes: return ["点赞", "likes"]
        case .comments: return ["评论", "comments"]
        case .favorites: return ["收藏", "favorites", "saves"]
        case .shares: return ["分享", "转发", "shares"]
        case .profileVisits: return ["主页访问", "主页浏览", "profilevisits"]
        case .followers: return ["新增关注", "新增粉丝", "followers"]
        case .privateMessages: return ["私信", "询盘", "privatemessages"]
        case .missingReasons: return ["缺失说明", "缺失原因", "missingreasons"]
        }
    }
}

struct BrandMetricImportPreview: Equatable {
    var headers: [String]
    var rows: [[String]]
    var mapping: [BrandMetricImportColumn: Int]

    var mappedDescription: String {
        BrandMetricImportColumn.allCases.compactMap { column in
            mapping[column].map { "\(headers[$0]) → \(column.displayName)" }
        }.joined(separator: "\n")
    }
}

enum BrandMetricImportService {
    static let templateHeader = "发布记录标识,采集时间,覆盖开始,覆盖结束,曝光,阅读,点赞,评论,收藏,分享,主页访问,新增关注,私信,缺失说明"

    static func preview(text: String) throws -> BrandMetricImportPreview {
        let clean = text.replacingOccurrences(of: "\u{feff}", with: "")
        guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrandMetricImportError.emptyFile
        }
        let delimiter: Character = clean.firstLine.contains("\t") ? "\t" : ","
        let table = parseDelimited(clean, delimiter: delimiter)
            .filter { row in row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let headers = table.first, table.count > 1 else { throw BrandMetricImportError.emptyFile }

        var mapping: [BrandMetricImportColumn: Int] = [:]
        for (index, header) in headers.enumerated() {
            let normalized = normalize(header)
            if let column = BrandMetricImportColumn.allCases.first(where: { $0.aliases.contains(normalized) }) {
                mapping[column] = index
            }
        }
        let required: [BrandMetricImportColumn] = [.publishIdentifier, .collectedAt, .periodStart, .periodEnd]
        let missing = required.filter { mapping[$0] == nil }.map(\.displayName)
        guard missing.isEmpty else { throw BrandMetricImportError.missingColumns(missing) }
        return BrandMetricImportPreview(headers: headers, rows: Array(table.dropFirst()), mapping: mapping)
    }

    static func makeSnapshots(
        from preview: BrandMetricImportPreview,
        publishRecords: [BrandPublishRecord],
        sourceFile: String
    ) throws -> [BrandMetricSnapshot] {
        try preview.rows.enumerated().map { offset, row in
            let displayRow = offset + 2
            let identifier = value(.publishIdentifier, row: row, mapping: preview.mapping)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identifier.isEmpty else {
                throw BrandMetricImportError.invalidRow(displayRow, "发布记录标识为空")
            }
            let matches = publishRecords.filter { record in
                record.id.uuidString.caseInsensitiveCompare(identifier) == .orderedSame
                    || (!record.platformPostID.isEmpty && record.platformPostID == identifier)
                    || (!record.platformLink.isEmpty && record.platformLink == identifier)
                    || (!record.snapshotTitle.isEmpty && record.snapshotTitle == identifier)
            }
            guard !matches.isEmpty else { throw BrandMetricImportError.unmatchedRecord(displayRow, identifier) }
            guard matches.count == 1, let record = matches.first else {
                throw BrandMetricImportError.ambiguousRecord(displayRow, identifier)
            }
            let collectedAt = try parseDate(value(.collectedAt, row: row, mapping: preview.mapping), row: displayRow, name: "采集时间")
            let periodStart = try parseDate(value(.periodStart, row: row, mapping: preview.mapping), row: displayRow, name: "覆盖开始")
            let periodEnd = try parseDate(value(.periodEnd, row: row, mapping: preview.mapping), row: displayRow, name: "覆盖结束")
            guard periodEnd > periodStart else {
                throw BrandMetricImportError.invalidRow(displayRow, "覆盖结束必须晚于覆盖开始")
            }

            let metrics: [(BrandMetricImportColumn, Int?)] = try [
                .exposure, .views, .likes, .comments, .favorites, .shares,
                .profileVisits, .followers, .privateMessages
            ].map { column in
                (column, try parseOptionalInt(value(column, row: row, mapping: preview.mapping), row: displayRow, name: column.displayName))
            }
            let metricByColumn = Dictionary(uniqueKeysWithValues: metrics)
            let provided = metrics.compactMap { $0.1 }
            var missingReasons = value(.missingReasons, row: row, mapping: preview.mapping)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let missingColumns = metrics.filter { $0.1 == nil }.map { $0.0.displayName }
            if !missingColumns.isEmpty && missingReasons.isEmpty {
                missingReasons = "未提供：\(missingColumns.joined(separator: "、"))"
            }
            guard !provided.isEmpty || !missingReasons.isEmpty else {
                throw BrandMetricImportError.invalidRow(displayRow, "至少填写一个指标或缺失说明")
            }

            return BrandMetricSnapshot(
                publishRecordID: record.id,
                collectedAt: collectedAt,
                periodStart: periodStart,
                periodEnd: periodEnd,
                method: .csv,
                exposure: metricByColumn[.exposure] ?? nil,
                views: metricByColumn[.views] ?? nil,
                likes: metricByColumn[.likes] ?? nil,
                comments: metricByColumn[.comments] ?? nil,
                favorites: metricByColumn[.favorites] ?? nil,
                shares: metricByColumn[.shares] ?? nil,
                profileVisits: metricByColumn[.profileVisits] ?? nil,
                followers: metricByColumn[.followers] ?? nil,
                privateMessages: metricByColumn[.privateMessages] ?? nil,
                missingReasons: missingReasons,
                sourceFile: sourceFile,
                isConfirmed: true
            )
        }
    }

    private static func value(
        _ column: BrandMetricImportColumn,
        row: [String],
        mapping: [BrandMetricImportColumn: Int]
    ) -> String {
        guard let index = mapping[column], row.indices.contains(index) else { return "" }
        return row[index]
    }

    private static func parseOptionalInt(_ raw: String, row: Int, name: String) throws -> Int? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
        guard !clean.isEmpty else { return nil }
        guard let value = Int(clean), value >= 0 else {
            throw BrandMetricImportError.invalidRow(row, "\(name) 必须是大于等于 0 的整数")
        }
        return value
    }

    private static func parseDate(_ raw: String, row: Int, name: String) throws -> Date {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        if let value = iso.date(from: clean) { return value }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let value = formatter.date(from: clean) { return value }
        }
        throw BrandMetricImportError.invalidRow(row, "\(name) 格式应为 yyyy-MM-dd 或 yyyy-MM-dd HH:mm")
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func parseDelimited(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if character == delimiter && !quoted {
                row.append(field)
                field = ""
            } else if (character == "\n" || character == "\r") && !quoted {
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" { index += 1 }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

private extension String {
    var firstLine: String {
        components(separatedBy: .newlines).first ?? self
    }
}
