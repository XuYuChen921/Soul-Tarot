import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BrandAssetLibraryPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrandAsset.updatedAt, order: .reverse) private var assets: [BrandAsset]
    @Query(sort: \ConsentRecord.confirmedAt, order: .reverse) private var consents: [ConsentRecord]
    @Query private var clients: [Client]
    @Query private var topics: [BrandContentTopic]
    @Query private var drafts: [BrandDraft]
    @Query private var publishRecords: [BrandPublishRecord]
    @Query(sort: \BrandAssetActionTask.createdAt, order: .reverse) private var tasks: [BrandAssetActionTask]
    @Query(sort: \BrandAssetAuditEvent.occurredAt, order: .reverse) private var audits: [BrandAssetAuditEvent]
    @Query(sort: \BrandAssetUsage.occurredAt, order: .reverse) private var usages: [BrandAssetUsage]

    @State private var showingConsent = false
    @State private var showingAsset = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private var anonymousConsents: [ConsentRecord] {
        consents.filter { $0.type == .anonymousContentUse }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("素材与匿名授权").font(.title2.bold())
                    Text("客户资料默认禁止使用；只有独立同意、去身份化双检和平台范围同时有效，才会进入内容工作台。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("登记独立同意") { showingConsent = true }
                    .buttonStyle(.bordered)
                #if os(macOS)
                Button("新增素材") { showingAsset = true }
                    .buttonStyle(.borderedProminent)
                #endif
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                metric("可用素材", assets.filter { $0.permission == .usable }.count, "checkmark.shield.fill", .green)
                metric("待核验", assets.filter { $0.permission == .pendingReview }.count, "person.badge.clock", .orange)
                metric("已撤回/禁止", assets.filter { $0.permission == .withdrawn || $0.permission == .prohibited }.count, "nosign", .red)
                metric("待处理任务", tasks.filter { $0.status == .pending }.count, "checklist", .orange)
            }

            card("独立授权", icon: "signature") {
                if anonymousConsents.isEmpty {
                    Text("暂无“匿名化内容使用”同意。客户素材不能进入内容生成。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(anonymousConsents) { consent in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clientName(consent.clientID)).font(.headline)
                                Text("\(consent.textVersion) · \(consent.confirmationMethod)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("范围：\(consent.permissionScope ?? "未填写")")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("平台：\(consent.allowedChannelsText ?? "未限制")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(
                                text: consentStatus(consent),
                                color: consent.isActiveAnonymousContentConsent ? .green : .red
                            )
                            if consent.isActiveAnonymousContentConsent {
                                Button("撤回") { withdraw(consent) }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                            }
                        }
                        Divider()
                    }
                }
            }
            .accessibilityIdentifier("brand-m3-consent-list")

            card("品牌素材库", icon: "photo.on.rectangle.angled") {
                if assets.isEmpty {
                    Text("暂无素材。Mac 可登记品牌自有、公开证明、客户匿名主题和内部参考素材。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assets) { asset in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(asset.name).font(.headline)
                                Spacer()
                                StatusBadge(text: asset.permission.rawValue, color: permissionColor(asset.permission))
                            }
                            Text("\(asset.category.rawValue) · \(asset.kind.rawValue) · \(asset.allowedChannelsText.isEmpty ? "未限制平台" : asset.allowedChannelsText)")
                                .font(.caption).foregroundStyle(.secondary)
                            if asset.isCustomerRelated {
                                Label(
                                    asset.hasCompletedDeidentification ? "已完成直接信息清理与第二次人工复核" : "去身份化复核未完成",
                                    systemImage: asset.hasCompletedDeidentification ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(asset.hasCompletedDeidentification ? .green : .orange)
                                Text(asset.deidentifiedSummary ?? "未填写去身份化摘要")
                                    .font(.subheadline).lineLimit(4)
                            }
                            if let hash = asset.sha256, !hash.isEmpty {
                                Text("完整性指纹：\(hash.prefix(16))…")
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            let useCount = usages.filter { $0.assetID == asset.id }.count
                            Text("使用留痕 \(useCount) 条")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }
            .accessibilityIdentifier("brand-m3-asset-list")

            card("撤回后待处理", icon: "exclamationmark.bubble.fill") {
                let pending = tasks.filter { $0.status == .pending }
                if pending.isEmpty {
                    Text("没有待处理任务。系统不会自动操作外部平台。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pending) { task in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.type.rawValue).font(.headline)
                                Text(task.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(task.type == .removeLocalFile ? "删除文件并完成" : "标记完成") {
                                complete(task)
                            }
                            .buttonStyle(.bordered)
                        }
                        Divider()
                    }
                }
            }
            .accessibilityIdentifier("brand-m3-task-list")

            card("操作留痕", icon: "clock.arrow.circlepath") {
                if audits.isEmpty {
                    Text("建立、复核、撤回和阻止动作会在这里追加记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(audits.prefix(20)) { audit in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(audit.action.rawValue) · \(assetName(audit.assetID))")
                                .font(.headline)
                            Text(audit.detail).font(.caption).foregroundStyle(.secondary)
                            Text("\(audit.actor) · \(audit.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }
        }
        .sheet(isPresented: $showingConsent) { NewAnonymousConsentSheet() }
        #if os(macOS)
        .sheet(isPresented: $showingAsset) { NewBrandAssetSheet() }
        #endif
        .alert("素材授权", isPresented: $showingAlert) {
            Button("知道了", role: .cancel) {}
        } message: { Text(alertMessage) }
    }

    private func withdraw(_ consent: ConsentRecord) {
        let result = BrandAssetWorkflowService.withdraw(
            consent: consent,
            assets: assets,
            topics: topics,
            drafts: drafts,
            publishRecords: publishRecords,
            method: "本机登记撤回"
        )
        result.events.forEach(modelContext.insert)
        result.tasks.forEach(modelContext.insert)
        do {
            try modelContext.save()
            alertMessage = "撤回已生效：相关素材与草稿已停止再次使用；已发布内容已建立人工处理任务。"
        } catch {
            alertMessage = error.localizedDescription
        }
        showingAlert = true
    }

    private func complete(_ task: BrandAssetActionTask) {
        do {
            if task.type == .removeLocalFile,
               let asset = assets.first(where: { $0.id == task.assetID }),
               let path = asset.relativePath, !path.isEmpty {
                try BrandAssetStorageService.removeFile(relativePath: path)
                asset.relativePath = nil
                asset.fileSize = nil
                asset.sha256 = nil
                asset.updatedAt = .now
                modelContext.insert(BrandAssetAuditEvent(
                    assetID: asset.id,
                    consentID: asset.consentID,
                    action: .deleted,
                    detail: "本机素材文件已删除，授权与撤回审计记录继续保留。"
                ))
            }
            task.status = .completed
            task.resolvedAt = .now
            try modelContext.save()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func consentStatus(_ consent: ConsentRecord) -> String {
        if consent.withdrawnAt != nil { return "已撤回" }
        if !consent.accepted { return "未接受" }
        if let expiresAt = consent.expiresAt, expiresAt < .now { return "已到期" }
        return "有效"
    }

    private func clientName(_ id: UUID) -> String {
        clients.first(where: { $0.id == id }).map { "\($0.clientCode) · \($0.displayName)" } ?? "客户记录不可见"
    }

    private func assetName(_ id: UUID) -> String { assets.first(where: { $0.id == id })?.name ?? "历史素材" }

    private func permissionColor(_ permission: BrandAssetPermission) -> Color {
        switch permission {
        case .usable: return .green
        case .pendingReview, .expired: return .orange
        case .withdrawn, .prohibited: return .red
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.largeTitle.bold().monospacedDigit()).foregroundStyle(color)
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct NewAnonymousConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.updatedAt, order: .reverse) private var clients: [Client]

    @State private var clientID: UUID?
    @State private var scope = "仅用于去身份化后的共性主题与经验分享"
    @State private var formats = "图文、匿名共性主题"
    @State private var allowWechat = true
    @State private var allowXHS = true
    @State private var hasExpiry = true
    @State private var expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var confirmationMethod = "微信文字确认"
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("独立同意") {
                    Picker("客户", selection: $clientID) {
                        Text("请选择").tag(nil as UUID?)
                        ForEach(clients) { Text("\($0.clientCode) · \($0.displayName)").tag($0.id as UUID?) }
                    }
                    TextField("允许范围", text: $scope, axis: .vertical)
                    TextField("允许形式", text: $formats)
                    Toggle("微信朋友圈", isOn: $allowWechat)
                    Toggle("小红书", isOn: $allowXHS)
                    Toggle("设置有效期", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("到期时间", selection: $expiresAt, in: Date.now...) }
                    TextField("确认方式", text: $confirmationMethod)
                }
                Section("必须告知") {
                    Text("该同意独立于咨询、录音、照片和本地 AI 同意；客户可随时撤回。撤回后素材和未发布草稿立即停用，外部已发布内容进入人工处理任务。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("登记匿名化内容使用同意")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认并保存") { save() } }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func save() {
        guard let clientID else { errorMessage = "请选择客户。"; return }
        let channels = [allowWechat ? BrandDistributionChannel.wechatMoments.rawValue : nil,
                        allowXHS ? BrandDistributionChannel.xiaohongshu.rawValue : nil].compactMap { $0 }
        guard !channels.isEmpty else { errorMessage = "至少选择一个允许平台。"; return }
        let version = "ANON-\(Date.now.formatted(.iso8601.year().month().day().timeZone(separator: .omitted)))"
        let expiryText = hasExpiry ? expiresAt.formatted(date: .numeric, time: .omitted) : "未限定"
        let snapshot = "允许范围：\(scope)\n允许形式：\(formats)\n允许平台：\(channels.joined(separator: "、"))\n有效期：\(expiryText)\n撤回方式：随时联系服务方并由本机登记"
        modelContext.insert(ConsentRecord(
            clientID: clientID,
            type: .anonymousContentUse,
            textVersion: version,
            textSnapshot: snapshot,
            accepted: true,
            confirmationMethod: confirmationMethod,
            permissionScope: scope,
            allowedChannelsText: channels.joined(separator: "，"),
            allowedFormatsText: formats,
            expiresAt: hasExpiry ? expiresAt : nil,
            withdrawalMethod: "联系服务方登记撤回"
        ))
        do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}

#if os(macOS)
private struct NewBrandAssetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.updatedAt, order: .reverse) private var clients: [Client]
    @Query(sort: \ConsentRecord.confirmedAt, order: .reverse) private var consents: [ConsentRecord]

    @State private var name = ""
    @State private var kind: BrandAssetType = .photo
    @State private var category: BrandAssetCategory = .brandOwned
    @State private var owner = "心塔"
    @State private var source = "本人提供"
    @State private var clientID: UUID?
    @State private var consentID: UUID?
    @State private var allowWechat = true
    @State private var allowXHS = true
    @State private var scope = "品牌内容使用"
    @State private var formats = "图文"
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var anonymousSummary = ""
    @State private var directRemoved = false
    @State private var indirectReviewed = false
    @State private var secondReviewed = false
    @State private var reviewer = ""
    @State private var selectedFile: URL?
    @State private var showingImporter = false
    @State private var errorMessage = ""

    private var activeConsents: [ConsentRecord] {
        consents.filter {
            $0.type == .anonymousContentUse && $0.accepted && $0.withdrawnAt == nil
                && ($0.expiresAt == nil || $0.expiresAt! >= .now)
                && (clientID == nil || $0.clientID == clientID)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("素材信息") {
                    TextField("素材名称", text: $name)
                    Picker("分类", selection: $category) {
                        ForEach(BrandAssetCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("类型", selection: $kind) {
                        ForEach(BrandAssetType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("所有者", text: $owner)
                    TextField("来源", text: $source)
                    Button(selectedFile == nil ? "选择本地文件（可选）" : "已选择：\(selectedFile!.lastPathComponent)") {
                        showingImporter = true
                    }
                }
                if category == .customerRelated {
                    Section("客户独立授权") {
                        Picker("客户", selection: $clientID) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(clients) { Text("\($0.clientCode) · \($0.displayName)").tag($0.id as UUID?) }
                        }
                        Picker("匿名化内容使用同意", selection: $consentID) {
                            Text("请选择有效同意").tag(nil as UUID?)
                            ForEach(activeConsents) { Text("\($0.textVersion) · \($0.confirmedAt.formatted(date: .abbreviated, time: .omitted))").tag($0.id as UUID?) }
                        }
                    }
                    Section("去身份化双检") {
                        TextField("仅保存去身份化摘要", text: $anonymousSummary, axis: .vertical).lineLimit(5...12)
                        Toggle("姓名、昵称、联系方式、精确日期地点已移除", isOn: $directRemoved)
                        Toggle("职业单位和可组合识别细节已复核", isOn: $indirectReviewed)
                        Toggle("已完成第二次人工核对", isOn: $secondReviewed)
                        TextField("第二复核人", text: $reviewer)
                        Text("不得导入或使用原始录音片段；摘要仍命中身份线索时会拒绝保存为可用素材。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("使用边界") {
                    Toggle("微信朋友圈", isOn: $allowWechat)
                    Toggle("小红书", isOn: $allowXHS)
                    TextField("允许范围", text: $scope)
                    TextField("允许形式", text: $formats)
                    Toggle("设置有效期", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("到期时间", selection: $expiresAt, in: Date.now...) }
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("新增品牌素材")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
        }
        .frame(minWidth: 560, minHeight: 760)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url): selectedFile = url
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { errorMessage = "素材名称不能为空。"; return }
        let channels = [allowWechat ? BrandDistributionChannel.wechatMoments.rawValue : nil,
                        allowXHS ? BrandDistributionChannel.xiaohongshu.rawValue : nil].compactMap { $0 }
        guard !channels.isEmpty else { errorMessage = "至少选择一个允许平台。"; return }
        if category == .customerRelated {
            guard clientID != nil, consentID != nil else { errorMessage = "客户素材必须关联客户和有效独立同意。"; return }
            guard directRemoved, indirectReviewed, secondReviewed,
                  !reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = BrandAssetWorkflowError.deidentificationIncomplete.localizedDescription
                return
            }
            let risks = BrandAssetWorkflowService.identityRisks(in: anonymousSummary)
            guard !anonymousSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = BrandAssetWorkflowError.emptyAnonymousSummary.localizedDescription
                return
            }
            guard risks.isEmpty else { errorMessage = BrandAssetWorkflowError.identityRisk(risks).localizedDescription; return }
            if let selectedFile,
               ["m4a", "mp3", "wav", "aac", "caf"].contains(selectedFile.pathExtension.lowercased()) {
                errorMessage = "客户相关素材禁止导入原始录音片段。"
                return
            }
        }

        let assetID = UUID()
        var fileInfo: (relativePath: String, size: Int64, sha256: String)?
        do {
            if let selectedFile { fileInfo = try BrandAssetStorageService.importFile(from: selectedFile, assetID: assetID) }
            let permission: BrandAssetPermission = {
                switch category {
                case .referenceOnly: return .prohibited
                case .prohibited: return .prohibited
                default: return .usable
                }
            }()
            let asset = BrandAsset(
                id: assetID,
                name: cleanName,
                kind: kind,
                source: source,
                owner: owner,
                permission: permission,
                allowedChannelsText: channels.joined(separator: "，"),
                expiryAt: hasExpiry ? expiresAt : nil,
                useScope: scope,
                note: category == .customerRelated ? "仅保留去身份化摘要；禁止使用原始录音片段" : "",
                category: category,
                clientID: clientID,
                consentID: consentID,
                originalFilename: selectedFile?.lastPathComponent,
                relativePath: fileInfo?.relativePath,
                fileSize: fileInfo?.size,
                sha256: fileInfo?.sha256,
                deidentifiedSummary: category == .customerRelated ? anonymousSummary.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                directIdentifiersRemoved: directRemoved,
                indirectIdentifiersReviewed: indirectReviewed,
                secondReviewCompleted: secondReviewed,
                secondReviewer: reviewer,
                reviewedAt: category == .customerRelated ? .now : nil,
                allowedFormatsText: formats
            )
            if category == .customerRelated {
                let consent = consentID.flatMap { id in consents.first(where: { $0.id == id }) }
                for channel in BrandDistributionChannel.allCases where channels.contains(channel.rawValue) {
                    try BrandAssetWorkflowService.validate(asset: asset, consent: consent, channel: channel)
                }
            }
            modelContext.insert(asset)
            modelContext.insert(BrandAssetAuditEvent(
                assetID: asset.id,
                consentID: asset.consentID,
                action: category == .customerRelated ? .reviewed : .created,
                detail: category == .customerRelated ? "独立同意和两次去身份化检查均已保存。" : "素材已登记并保存使用边界。"
            ))
            try modelContext.save()
            dismiss()
        } catch {
            if let path = fileInfo?.relativePath { try? BrandAssetStorageService.removeFile(relativePath: path) }
            errorMessage = error.localizedDescription
        }
    }
}
#endif
