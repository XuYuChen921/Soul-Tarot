import Foundation

struct BrandAttributionSummary: Equatable {
    var inquiryCount: Int
    var contentAttributedClientCount: Int
    var platformOnlyCount: Int
    var unattributedCount: Int
    var appointmentCount: Int
    var orderCount: Int
    var netCashCents: Int

    static let empty = BrandAttributionSummary(
        inquiryCount: 0,
        contentAttributedClientCount: 0,
        platformOnlyCount: 0,
        unattributedCount: 0,
        appointmentCount: 0,
        orderCount: 0,
        netCashCents: 0
    )
}

struct BrandWeeklyReviewDraft: Equatable {
    var periodStart: Date
    var periodEnd: Date
    var plannedGenerateAt: Date
    var generatedAt: Date
    var facts: String
    var interpretation: String
    var best: String
    var worst: String
    var conversion: String
    var wechatRole: String
    var xiaohongshuRole: String
    var dataGaps: String
    var continueDoing: String
    var stopDoing: String
    var experiments: String
    var usedSnapshotIDs: [UUID]
}

enum BrandGrowthAnalyticsService {
    static func naturalWeek(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var local = calendar
        local.firstWeekday = 2
        local.minimumDaysInFirstWeek = 4
        let start = local.dateInterval(of: .weekOfYear, for: date)?.start
            ?? local.startOfDay(for: date)
        let end = local.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(604_800)
        return DateInterval(start: start, end: end)
    }

    static func previousNaturalWeek(reference: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let current = naturalWeek(containing: reference, calendar: calendar)
        let priorDate = calendar.date(byAdding: .day, value: -1, to: current.start) ?? current.start.addingTimeInterval(-86_400)
        return naturalWeek(containing: priorDate, calendar: calendar)
    }

    static func nextPlannedReview(after date: Date = .now, calendar: Calendar = .current) -> Date {
        let current = naturalWeek(containing: date, calendar: calendar)
        let nextMonday = current.end
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextMonday) ?? nextMonday
    }

    static func latestConfirmedSnapshots(
        _ snapshots: [BrandMetricSnapshot],
        overlapping interval: DateInterval? = nil
    ) -> [BrandMetricSnapshot] {
        let candidates = snapshots.filter { snapshot in
            guard snapshot.isConfirmed else { return false }
            guard let interval else { return true }
            return snapshot.periodStart < interval.end && snapshot.periodEnd > interval.start
        }
        return Dictionary(grouping: candidates, by: \.publishRecordID)
            .compactMap { _, values in values.max(by: { $0.collectedAt < $1.collectedAt }) }
            .sorted { $0.collectedAt > $1.collectedAt }
    }

    static func attributionSummary(
        touchpoints: [BrandMarketingTouchpoint],
        appointments: [Appointment],
        orders: [ServiceOrder],
        appointmentPayments: [PaymentTransaction],
        orderPayments: [OrderPaymentTransaction],
        interval: DateInterval
    ) -> BrandAttributionSummary {
        let active = touchpoints.filter(\.isActive)
        let inquiries = active.filter { interval.containsHalfOpen($0.firstContactAt) }
        let attributed = active.filter(\.hasContentEvidence)
        let attributedClientIDs = Set(attributed.map(\.clientID))

        let validAppointments = appointments.filter {
            attributedClientIDs.contains($0.clientID)
                && interval.containsHalfOpen($0.startAt)
                && $0.status != .rescheduled
                && $0.status != .pendingRules
        }
        let validOrders = orders.filter {
            attributedClientIDs.contains($0.clientID)
                && interval.containsHalfOpen($0.placedAt)
                && $0.status != .cancelled
        }
        let appointmentCash = appointmentPayments.filter {
            attributedClientIDs.contains($0.clientID) && interval.containsHalfOpen($0.occurredAt)
        }.reduce(0) { $0 + $1.signedCashCents }
        let orderCash = orderPayments.filter {
            attributedClientIDs.contains($0.clientID) && interval.containsHalfOpen($0.occurredAt)
        }.reduce(0) { $0 + $1.signedCashCents }

        return BrandAttributionSummary(
            inquiryCount: inquiries.count,
            contentAttributedClientCount: Set(attributed.map(\.clientID)).count,
            platformOnlyCount: inquiries.filter { $0.evidence == .platformOnly }.count,
            unattributedCount: inquiries.filter { $0.evidence == .unattributed }.count,
            appointmentCount: validAppointments.count,
            orderCount: validOrders.count,
            netCashCents: appointmentCash + orderCash
        )
    }

    static func makeWeeklyReview(
        interval: DateInterval,
        publishRecords: [BrandPublishRecord],
        snapshots: [BrandMetricSnapshot],
        touchpoints: [BrandMarketingTouchpoint],
        appointments: [Appointment],
        orders: [ServiceOrder],
        appointmentPayments: [PaymentTransaction],
        orderPayments: [OrderPaymentTransaction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BrandWeeklyReviewDraft {
        let periodPosts = publishRecords.filter {
            guard let publishedAt = $0.publishedAt else { return false }
            return interval.containsHalfOpen(publishedAt)
        }
        let confirmedSnapshots = latestConfirmedSnapshots(snapshots, overlapping: interval)
        let attribution = attributionSummary(
            touchpoints: touchpoints,
            appointments: appointments,
            orders: orders,
            appointmentPayments: appointmentPayments,
            orderPayments: orderPayments,
            interval: interval
        )

        let ranked = confirmedSnapshots.sorted {
            engagementScore($0) > engagementScore($1)
        }
        let recordByID = Dictionary(uniqueKeysWithValues: publishRecords.map { ($0.id, $0) })
        let bestSnapshot = ranked.first
        let worstSnapshot = ranked.count > 1 ? ranked.last : nil
        let bestName = bestSnapshot.flatMap { recordByID[$0.publishRecordID]?.snapshotTitle }
        let worstName = worstSnapshot.flatMap { recordByID[$0.publishRecordID]?.snapshotTitle }

        let facts = [
            "事实｜本周实际发布 \(periodPosts.count) 条。",
            "事实｜采用 \(confirmedSnapshots.count) 条最新人工确认快照，不累计重复快照。",
            "事实｜记录询盘 \(attribution.inquiryCount) 位，其中确认到具体内容 \(attribution.contentAttributedClientCount) 位。",
            "事实｜归因预约 \(attribution.appointmentCount) 笔、订单 \(attribution.orderCount) 笔、现金净实收 \(attribution.netCashCents.yuanText)。"
        ].joined(separator: "\n")

        let interpretation: String
        if let bestSnapshot, let bestName {
            interpretation = "解释｜在本周可用的最新确认快照中，《\(bestName)》互动合计 \(engagementScore(bestSnapshot))，表现相对更高；这只是相关性信号，不能单独证明因果。"
        } else {
            interpretation = "解释｜当前没有足够的确认快照，暂不判断内容优劣。"
        }

        let postsWithoutSnapshot = periodPosts.filter { post in
            !confirmedSnapshots.contains(where: { $0.publishRecordID == post.id })
        }
        var gaps: [String] = []
        if !postsWithoutSnapshot.isEmpty { gaps.append("有 \(postsWithoutSnapshot.count) 条本周发布内容没有确认数据快照") }
        if attribution.platformOnlyCount > 0 { gaps.append("有 \(attribution.platformOnlyCount) 位询盘只确认到平台") }
        if attribution.unattributedCount > 0 { gaps.append("有 \(attribution.unattributedCount) 位询盘无法确认来源") }
        if confirmedSnapshots.contains(where: hasMissingMetric) { gaps.append("部分平台指标未提供，未按 0 补齐") }
        if gaps.isEmpty { gaps.append("本周已录入字段未发现明显缺口；仍需人工核对平台后台") }

        let bestText = bestName.map { "继续观察《\($0)》的结构与行动提示。" } ?? "暂无足够数据选出最佳内容。"
        let worstText = worstName.map { "《\($0)》相对较低，先核对曝光和发布时间再调整。" } ?? "暂无足够的第二条内容用于低表现对照。"
        let conversion = "确认内容归因客户 \(attribution.contentAttributedClientCount) 位，归因现金净实收 \(attribution.netCashCents.yuanText)；未确认来源的数据未计入。"
        let experiments = [
            "1. 复用本周相对高表现内容的开头结构，只改变主题。",
            "2. 对待补数据内容在发布后 24–48 小时补一条确认快照。",
            "3. 为一个平台版本设置单一行动提示，观察确认询盘变化。"
        ].joined(separator: "\n")

        return BrandWeeklyReviewDraft(
            periodStart: interval.start,
            periodEnd: interval.end,
            plannedGenerateAt: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: interval.end) ?? interval.end,
            generatedAt: now,
            facts: facts,
            interpretation: interpretation,
            best: bestText,
            worst: worstText,
            conversion: conversion,
            wechatRole: channelRole(.wechatMoments, records: periodPosts, snapshots: confirmedSnapshots),
            xiaohongshuRole: channelRole(.xiaohongshu, records: periodPosts, snapshots: confirmedSnapshots),
            dataGaps: gaps.map { "• \($0)" }.joined(separator: "\n"),
            continueDoing: bestName.map { "继续：保留《\($0)》中已得到反馈的表达结构。" } ?? "继续：先稳定补齐真实数据。",
            stopDoing: "停止：不把缺失值当作 0，不把只有平台线索的客户强行归到具体内容。",
            experiments: experiments,
            usedSnapshotIDs: confirmedSnapshots.map(\.id)
        )
    }

    private static func engagementScore(_ snapshot: BrandMetricSnapshot) -> Int {
        [snapshot.likes, snapshot.comments, snapshot.favorites, snapshot.shares]
            .compactMap { $0 }
            .reduce(0, +)
    }

    private static func hasMissingMetric(_ snapshot: BrandMetricSnapshot) -> Bool {
        [snapshot.exposure, snapshot.views, snapshot.likes, snapshot.comments, snapshot.favorites,
         snapshot.shares, snapshot.profileVisits, snapshot.followers, snapshot.privateMessages]
            .contains(where: { $0 == nil })
    }

    private static func channelRole(
        _ channel: BrandDistributionChannel,
        records: [BrandPublishRecord],
        snapshots: [BrandMetricSnapshot]
    ) -> String {
        let channelRecords = records.filter { $0.channel == channel }
        let ids = Set(channelRecords.map(\.id))
        let channelSnapshots = snapshots.filter { ids.contains($0.publishRecordID) }
        guard !channelRecords.isEmpty else { return "本周未发布，暂无角色判断。" }
        guard !channelSnapshots.isEmpty else { return "已发布 \(channelRecords.count) 条，但缺少确认快照。" }
        let interactions = channelSnapshots.reduce(0) { $0 + engagementScore($1) }
        return "发布 \(channelRecords.count) 条，最新确认快照互动合计 \(interactions)；继续结合询盘证据判断平台角色。"
    }
}

private extension DateInterval {
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
