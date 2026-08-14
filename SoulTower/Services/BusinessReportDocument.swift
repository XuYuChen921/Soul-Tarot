import SwiftUI
import UniformTypeIdentifiers

struct BusinessReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(summary: BusinessSummary, transactions: [BusinessCashEntry], periodName: String) {
        var rows: [[String]] = [
            ["心塔经营流水报表"],
            ["统计周期", periodName],
            ["现金收入", Self.centsText(summary.cashIncomeCents)],
            ["退款", Self.centsText(summary.refundCents)],
            ["现金净实收", Self.centsText(summary.netCashCents)],
            ["余额抵扣", Self.centsText(summary.balanceOffsetCents)],
            [],
            ["发生时间", "客户编号", "服务项目", "来源", "流水类型", "收付款方式", "金额（元）", "备注"]
        ]

        let dateStyle = Date.ISO8601FormatStyle(dateSeparator: .dash, timeSeparator: .colon)
        rows.append(contentsOf: transactions.map { transaction in
            [
                transaction.occurredAt.formatted(dateStyle),
                transaction.clientCode,
                transaction.serviceNameSnapshot,
                transaction.sourceName,
                transaction.kind.rawValue,
                transaction.method.rawValue,
                Self.centsText(transaction.displayAmountCents),
                transaction.note
            ]
        })

        let csv = "\u{FEFF}" + rows.map { $0.map(Self.csvField).joined(separator: ",") }.joined(separator: "\r\n")
        data = Data(csv.utf8)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    private static func csvField(_ value: String) -> String {
        let protected: String
        if let first = value.first, ["=", "+", "-", "@"].contains(String(first)) {
            protected = "'" + value
        } else {
            protected = value
        }
        return "\"\(protected.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func centsText(_ cents: Int) -> String {
        NSDecimalNumber(value: cents).dividing(by: 100).stringValue
    }
}
