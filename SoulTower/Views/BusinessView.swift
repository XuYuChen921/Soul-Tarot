import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum BusinessPeriodPreset: String, CaseIterable, Identifiable {
    case currentMonth = "本月"
    case previousMonth = "上月"
    case currentYear = "本年"
    case all = "全部"

    var id: String { rawValue }

    func interval(reference: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .currentMonth:
            return calendar.dateInterval(of: .month, for: reference)
        case .previousMonth:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: reference) else { return nil }
            return calendar.dateInterval(of: .month, for: previous)
        case .currentYear:
            return calendar.dateInterval(of: .year, for: reference)
        case .all:
            return nil
        }
    }
}

struct BusinessView: View {
    @Query(sort: \Appointment.startAt, order: .reverse) private var appointments: [Appointment]
    @Query(sort: \PaymentTransaction.occurredAt, order: .reverse) private var transactions: [PaymentTransaction]
    @Query(sort: \ServiceOrder.placedAt, order: .reverse) private var serviceOrders: [ServiceOrder]
    @Query(sort: \OrderPaymentTransaction.occurredAt, order: .reverse) private var orderTransactions: [OrderPaymentTransaction]
    @State private var selectedPeriod: BusinessPeriodPreset = .currentMonth
    @State private var reportDocument: BusinessReportDocument?
    @State private var showingExporter = false
    @State private var exportMessage = ""

    private var summary: BusinessSummary {
        BusinessAnalytics.summary(
            appointments: appointments,
            transactions: transactions,
            serviceOrders: serviceOrders,
            orderTransactions: orderTransactions,
            interval: selectedPeriod.interval()
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                periodHeader
                metrics
                cashBreakdown
                appointmentStatusSection
                serviceSection
                recentTransactionsSection
                accountingNotice
            }
            .padding()
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .navigationTitle("经营总览")
        .toolbar {
            ToolbarItemGroup {
                Button { prepareExport() } label: {
                    Label("导出报表", systemImage: "square.and.arrow.up")
                }
                Picker("统计周期", selection: $selectedPeriod) {
                    ForEach(BusinessPeriodPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: reportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "心塔经营流水-\(selectedPeriod.rawValue)-\(Date.now.formatted(.dateTime.year().month().day()))"
        ) { result in
            switch result {
            case .success: exportMessage = "报表已导出"
            case .failure: exportMessage = "报表导出失败"
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !exportMessage.isEmpty {
                Text(exportMessage)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

    private var periodHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("真实收付款")
                    .font(.largeTitle.bold())
                Text(periodDescription)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: selectedPeriod.rawValue, color: BrandTheme.teal)
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 14)], spacing: 14) {
            MetricCard(title: "现金收入", value: summary.cashIncomeCents.yuanText, note: "实收", icon: "arrow.down.circle.fill", tint: .green)
            MetricCard(title: "退款", value: summary.refundCents.yuanText, note: "实退", icon: "arrow.uturn.backward.circle.fill", tint: .red)
            MetricCard(title: "现金净实收", value: summary.netCashCents.yuanText, note: "收入－退款", icon: "banknote.fill", tint: BrandTheme.teal)
            MetricCard(title: "待确认付款", value: "\(summary.pendingPaymentCount)", note: "笔", icon: "clock.badge.exclamationmark", tint: .orange)
            MetricCard(title: "已完成", value: "\(summary.completedCount)", note: "场", icon: "checkmark.circle.fill", tint: BrandTheme.teal)
            MetricCard(title: "取消 / 爽约", value: "\(summary.cancelledCount + summary.noShowCount)", note: "条", icon: "calendar.badge.exclamationmark", tint: .red)
            MetricCard(title: "套餐 / 项目订单", value: "\(summary.serviceOrderCount)", note: "笔", icon: "shippingbox.fill", tint: BrandTheme.gold)
        }
    }

    private var cashBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("流水构成", subtitle: "按实际发生时间汇总")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                breakdownCard("咨询费", amount: summary.servicePaymentCents, icon: "person.2.fill", color: BrandTheme.teal)
                breakdownCard("加急费", amount: summary.rushFeeCents, icon: "bolt.fill", color: .orange)
                breakdownCard("改期费", amount: summary.rescheduleFeeCents, icon: "calendar.badge.clock", color: .purple)
                breakdownCard("其他收款", amount: summary.otherIncomeCents, icon: "plus.circle.fill", color: .blue)
                breakdownCard("余额抵扣", amount: summary.balanceOffsetCents, icon: "arrow.triangle.2.circlepath", color: .indigo)
            }
        }
    }

    private func breakdownCard(_ title: String, amount: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 26)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(amount.yuanText).font(.headline.monospacedDigit())
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var appointmentStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("预约付款状态", subtitle: "共 \(summary.appointmentCount) 笔有效预约")
            if summary.appointmentCount == 0 {
                EmptyStateView(icon: "chart.bar.xaxis", title: "当前周期暂无经营数据", message: "新建预约并记录收付款后，这里会自动汇总。")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(PaymentStatus.allCases) { status in
                        HStack {
                            Text(status.rawValue).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(summary.paymentStatusCounts[status, default: 0])")
                                .font(.title2.bold().monospacedDigit())
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("服务项目表现", subtitle: "按现金净实收排序")
            if summary.services.isEmpty {
                Text("当前周期暂无可汇总的服务项目。")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.services.enumerated()), id: \.element.id) { index, service in
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles").foregroundStyle(BrandTheme.gold).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(service.serviceName).font(.headline)
                                Text("预约 \(service.appointmentCount) 笔 · 已完成 \(service.completedCount) 场")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(service.netCashCents.yuanText)
                                .font(.headline.monospacedDigit()).foregroundStyle(BrandTheme.deepGreen)
                        }
                        .padding(.vertical, 14)
                        if index < summary.services.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                .padding(.horizontal, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("最近流水", subtitle: "最多显示 12 条")
            if summary.recentTransactions.isEmpty {
                Text("当前周期暂无收付款流水。")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(summary.recentTransactions) { transaction in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(transaction.clientCode) · \(transaction.kind.rawValue)")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(transaction.sourceName) · \(transaction.serviceNameSnapshot) · \(transaction.method.rawValue) · \(transaction.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.displayAmountCents.yuanText)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(transaction.kind == .refund ? .red : .primary)
                        }
                        .padding(.vertical, 11)
                        Divider()
                    }
                }
                .padding(.horizontal, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var accountingNotice: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("统计口径", systemImage: "info.circle.fill")
                .font(.headline).foregroundStyle(BrandTheme.deepGreen)
            Text("V0.4 起，金额只汇总手工记录的本地收付款流水，不连接微信或银行卡。预约数量按咨询时间归期，金额按收付款实际发生时间归期。")
            if summary.unverifiedLegacyCount > 0 {
                Label("有 \(summary.unverifiedLegacyCount) 条旧版付款状态已自动转换为待核对流水。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if summary.rescheduleFeeNoteCount > summary.rescheduleFeeCents / max(DefaultBusinessRules.lateRescheduleFeeCents, 1) {
                Label("部分历史改期费仍只存在于备注中，请核对后手工补录。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandTheme.mint.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.bold())
            Spacer()
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var periodDescription: String {
        guard let interval = selectedPeriod.interval() else { return "全部历史预约与收付款流水" }
        let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let format = Date.FormatStyle(date: .numeric, time: .omitted, locale: Locale(identifier: "zh_CN"))
        return "\(interval.start.formatted(format))—\(end.formatted(format))"
    }

    private func prepareExport() {
        let periodTransactions = BusinessAnalytics.transactions(
            transactions,
            appointments: appointments,
            orderTransactions: orderTransactions,
            serviceOrders: serviceOrders,
            interval: selectedPeriod.interval()
        )
        reportDocument = BusinessReportDocument(
            summary: summary,
            transactions: periodTransactions,
            periodName: "\(selectedPeriod.rawValue)（\(periodDescription)）"
        )
        showingExporter = true
    }
}
