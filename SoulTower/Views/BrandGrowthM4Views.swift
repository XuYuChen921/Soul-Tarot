import SwiftData
import SwiftUI

struct BrandPlatformAutomationPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrandPlatformConnection.createdAt) private var connections: [BrandPlatformConnection]
    @Query(sort: \BrandSyncRun.requestedAt, order: .reverse) private var syncRuns: [BrandSyncRun]
    @Query(sort: \BrandExperiment.createdAt, order: .reverse) private var experiments: [BrandExperiment]
    @Query(sort: \BrandPublishRecord.createdAt, order: .reverse) private var publishRecords: [BrandPublishRecord]
    @Query(sort: \BrandMetricSnapshot.collectedAt, order: .reverse) private var snapshots: [BrandMetricSnapshot]

    @State private var showingNewExperiment = false
    @State private var message = ""
    @State private var showingMessage = false

    private var publishedRecords: [BrandPublishRecord] {
        publishRecords.filter(\.isPublished)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            card("M4 自动化边界", icon: "network.badge.shield.half.filled") {
                Text("只有真实账号、官方权限和接口范围全部验收后，才允许自动同步。当前朋友圈与小红书笔记指标继续使用人工录入或 CSV；自动化失败不会删除或覆盖任何历史快照。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    StatusBadge(text: "不使用爬虫", color: .green)
                    StatusBadge(text: "令牌只进钥匙串", color: BrandTheme.teal)
                    StatusBadge(text: "快照只新增", color: BrandTheme.gold)
                }
            }
            .accessibilityIdentifier("brand-m4-boundary")

            card("平台能力核验", icon: "checkmark.seal.fill") {
                if connections.isEmpty {
                    Text("正在建立本机平台能力登记。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(connections) { connection in
                        connectionRow(connection)
                        if connection.id != connections.last?.id { Divider() }
                    }
                }
            }
            .accessibilityIdentifier("brand-m4-connections")

            card("同步状态与失败恢复", icon: "arrow.triangle.2.circlepath") {
                if syncRuns.isEmpty {
                    Text("尚无自动同步记录。当前人工录入和 CSV 导入不受影响；未来接入正式接口后，每次同步都会保留独立结果。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncRuns.prefix(8)) { run in
                        let connection = connections.first { $0.id == run.connectionID }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(connection?.platform.rawValue ?? "历史平台")
                                    .font(.headline)
                                Spacer()
                                StatusBadge(text: run.status.rawValue, color: runColor(run.status))
                            }
                            Text("\(run.requestedAt.formatted(date: .abbreviated, time: .shortened)) · 新增 \(run.importedCount) · 跳过重复 \(run.skippedDuplicateCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !run.safeMessage.isEmpty {
                                Text(run.safeMessage).font(.caption).foregroundStyle(run.status == .failed ? .orange : .secondary)
                            }
                        }
                        if run.id != syncRuns.prefix(8).last?.id { Divider() }
                    }
                }
            }
            .accessibilityIdentifier("brand-m4-sync-history")

            card("持续优化实验", icon: "flask.fill") {
                HStack {
                    Text("对比栏目、标题、发布时间或行动提示。系统只呈现已确认快照的事实，不自动宣称因果。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("新建实验") { showingNewExperiment = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(publishedRecords.count < 2)
                }
                if publishedRecords.count < 2 {
                    Text("至少需要两条已发布内容才能建立对比实验。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if experiments.isEmpty {
                    Text("暂无实验记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(experiments) { experiment in
                        experimentRow(experiment)
                        if experiment.id != experiments.last?.id { Divider() }
                    }
                }
            }
            .accessibilityIdentifier("brand-m4-experiments")
        }
        .task {
            do {
                try BrandPlatformCapabilityRegistry.registerDefaults(context: modelContext)
            } catch {
                message = "平台能力登记失败：\(error.localizedDescription)"
                showingMessage = true
            }
        }
        .sheet(isPresented: $showingNewExperiment) {
            NewBrandExperimentSheet(publishRecords: publishedRecords)
        }
        .alert("平台自动化", isPresented: $showingMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    @ViewBuilder
    private func connectionRow(_ connection: BrandPlatformConnection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(connection.platform.rawValue).font(.headline)
                    Text(connection.accountType).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: connection.status.rawValue, color: connectionColor(connection.status))
            }
            LabeledContent("已核验能力", value: connection.capability.rawValue)
                .font(.subheadline)
            Text(connection.verificationNote)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if let url = URL(string: connection.officialDocumentURL) {
                    Link("查看官方能力说明", destination: url)
                        .font(.caption)
                } else {
                    Text("官方说明地址待修复")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let last = connection.lastSuccessfulSyncAt {
                    let stale = BrandPlatformAutomationService.isStale(lastSuccessfulSyncAt: last)
                    Text(stale ? "上次成功已超过 48 小时，不视为最新" : "最近成功：\(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(stale ? .orange : .secondary)
                } else {
                    Text("尚无自动同步成功记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func experimentRow(_ experiment: BrandExperiment) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(experiment.title).font(.headline)
                StatusBadge(text: experiment.dimension.rawValue, color: BrandTheme.teal)
                Spacer()
                StatusBadge(text: experiment.status.rawValue, color: experiment.status == .completed ? .green : BrandTheme.gold)
            }
            Text("假设：\(experiment.hypothesis)").font(.subheadline)
            Text(BrandPlatformAutomationService.factualComparison(experiment: experiment, snapshots: snapshots))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !experiment.conclusion.isEmpty {
                Text("人工结论：\(experiment.conclusion)").font(.caption)
            }
            if experiment.status != .completed {
                Button("刷新事实并结束实验") {
                    experiment.factualComparison = BrandPlatformAutomationService.factualComparison(experiment: experiment, snapshots: snapshots)
                    experiment.status = .completed
                    experiment.endedAt = .now
                    experiment.updatedAt = .now
                    do {
                        try modelContext.save()
                    } catch {
                        message = error.localizedDescription
                        showingMessage = true
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func connectionColor(_ status: BrandPlatformConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .manualOnly: return BrandTheme.teal
        case .verificationRequired: return BrandTheme.gold
        case .tokenExpired, .syncFailed: return .orange
        }
    }

    private func runColor(_ status: BrandSyncRunStatus) -> Color {
        switch status {
        case .succeeded: return .green
        case .running: return BrandTheme.gold
        case .skipped: return BrandTheme.teal
        case .failed: return .orange
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct NewBrandExperimentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let publishRecords: [BrandPublishRecord]

    @State private var title = ""
    @State private var dimension: BrandExperimentDimension = .titleDirection
    @State private var hypothesis = ""
    @State private var variantALabel = "A"
    @State private var variantBLabel = "B"
    @State private var variantAID: UUID
    @State private var variantBID: UUID
    @State private var errorMessage = ""

    init(publishRecords: [BrandPublishRecord]) {
        self.publishRecords = publishRecords
        _variantAID = State(initialValue: publishRecords.first?.id ?? UUID())
        _variantBID = State(initialValue: publishRecords.dropFirst().first?.id ?? publishRecords.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("实验定义") {
                    TextField("实验名称", text: $title)
                    Picker("对比维度", selection: $dimension) {
                        ForEach(BrandExperimentDimension.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("假设（由人工提出）", text: $hypothesis, axis: .vertical)
                }
                Section("版本 A") {
                    TextField("版本标签", text: $variantALabel)
                    Picker("已发布内容", selection: $variantAID) {
                        ForEach(publishRecords) { Text(recordLabel($0)).tag($0.id) }
                    }
                }
                Section("版本 B") {
                    TextField("版本标签", text: $variantBLabel)
                    Picker("已发布内容", selection: $variantBID) {
                        ForEach(publishRecords) { Text(recordLabel($0)).tag($0.id) }
                    }
                }
                Section("判断边界") {
                    Text("只有两条内容的已确认指标会进入事实对比。曝光口径、发布时间或平台不同，都可能影响结果；最终结论必须由人工填写。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("新建优化实验")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("建立实验") { save() } }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private func recordLabel(_ record: BrandPublishRecord) -> String {
        "\(record.channel.rawValue) · \(record.snapshotTitle.isEmpty ? "未命名内容" : record.snapshotTitle)"
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHypothesis = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanHypothesis.isEmpty else {
            errorMessage = "请填写实验名称和假设。"
            return
        }
        guard variantAID != variantBID else {
            errorMessage = "版本 A 和 B 必须选择不同的已发布内容。"
            return
        }
        modelContext.insert(BrandExperiment(
            title: cleanTitle,
            dimension: dimension,
            hypothesis: cleanHypothesis,
            variantALabel: variantALabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A" : variantALabel,
            variantAPublishRecordID: variantAID,
            variantBLabel: variantBLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "B" : variantBLabel,
            variantBPublishRecordID: variantBID,
            status: .running
        ))
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
