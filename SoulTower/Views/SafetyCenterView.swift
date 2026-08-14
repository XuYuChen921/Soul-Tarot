import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

private enum SecuritySheetMode: String, Identifiable {
    case enable
    case change
    case disable

    var id: String { rawValue }
}

struct SafetyCenterView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var securityManager: AppSecurityManager
    @EnvironmentObject private var appState: AppState
    @Query private var clients: [Client]
    @Query private var appointments: [Appointment]
    @Query private var records: [ConsultationRecord]
    @Query private var mediaAssets: [MediaAsset]

    @State private var securitySheet: SecuritySheetMode?
    @State private var backupPassword = ""
    @State private var backupPasswordConfirmation = ""
    @State private var restorePassword = ""
    @State private var choosingBackupDestination = false
    @State private var choosingBackupToValidate = false
    @State private var choosingBackupToRestore = false
    @State private var pendingRestoreURL: URL?
    @State private var showingRestoreConfirmation = false
    @State private var showingDemoClearConfirmation = false
    @State private var isWorking = false
    @State private var statusMessage = ""
    @State private var pendingReminderCount = 0
    @StateObject private var audioSelfTest = AudioSelfTestRecorder()

    var body: some View {
        Form {
            appLockSection
            backupSection
            notificationSection
            audioDiagnosticSection
            dataMaintenanceSection
            versionSection

            if !statusMessage.isEmpty {
                Section("操作结果") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("安全中心")
        .sheet(item: $securitySheet) { mode in
            SecurityCredentialSheet(mode: mode)
                .environmentObject(securityManager)
        }
        .fileImporter(isPresented: $choosingBackupDestination, allowedContentTypes: [.folder]) {
            handleBackupDestination($0)
        }
        .fileImporter(isPresented: $choosingBackupToValidate, allowedContentTypes: [.folder]) {
            handleValidationSelection($0)
        }
        .fileImporter(isPresented: $choosingBackupToRestore, allowedContentTypes: [.folder]) {
            handleRestoreSelection($0)
        }
        .alert("恢复会替换本机业务资料", isPresented: $showingRestoreConfirmation) {
            Button("取消", role: .cancel) { pendingRestoreURL = nil }
            Button("验证并恢复", role: .destructive) { performRestore() }
        } message: {
            Text("恢复前会完整验证密码、数据和资料文件。应用锁凭据不会被替换；恢复成功后将重建未来预约提醒。")
        }
        .alert("清除所有演示数据", isPresented: $showingDemoClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) { clearDemoData() }
        } message: {
            Text("只删除客户编号 C-DEMO 或来源为“演示数据”的记录，不会删除正式客户。")
        }
        .task {
            await refreshNotificationStatus()
        }
        .onDisappear { audioSelfTest.cleanup() }
    }

    private var appLockSection: some View {
        Section("应用锁") {
            LabeledContent("状态", value: securityManager.isLockEnabled ? "已启用" : "未启用")
            LabeledContent("本机生物识别", value: securityManager.biometryLabel)

            if securityManager.isLockEnabled {
                Toggle("允许 \(securityManager.biometryLabel) 解锁", isOn: Binding(
                    get: { securityManager.biometricUnlockEnabled },
                    set: { securityManager.setBiometricUnlock($0) }
                ))
                .disabled(!securityManager.canUseBiometrics)

                Button("立即锁定") { securityManager.lock() }
                Button("修改应用密码") { securitySheet = .change }
                Button("关闭应用锁", role: .destructive) { securitySheet = .disable }
            } else {
                Button("启用应用密码") { securitySheet = .enable }
                    .buttonStyle(.borderedProminent)
            }
            Text("应用进入后台或切换离开时会立即锁定。密码明文不会写入磁盘；忘记密码无法读取应用锁凭据。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var backupSection: some View {
        Section("加密备份与恢复") {
            SecureField("新备份密码（至少 8 位）", text: $backupPassword)
            SecureField("再次输入新备份密码", text: $backupPasswordConfirmation)
            Button(isWorking ? "正在处理…" : "选择文件夹并创建加密备份") {
                guard backupPassword == backupPasswordConfirmation else {
                    statusMessage = "两次备份密码不一致。"
                    return
                }
                securityManager.suspendAutoLock()
                choosingBackupDestination = true
            }
            .disabled(isWorking || backupPassword.count < 8 || backupPasswordConfirmation.count < 8)

            Divider()
            SecureField("已有备份的密码", text: $restorePassword)
            HStack {
                Button("验证备份完整性") {
                    securityManager.suspendAutoLock()
                    choosingBackupToValidate = true
                }
                Button("从备份恢复", role: .destructive) {
                    securityManager.suspendAutoLock()
                    choosingBackupToRestore = true
                }
            }
            .disabled(isWorking || restorePassword.count < 8)

            Text("备份包含客户、服务、预约、确认记录、咨询文字、录音、照片、正式摘要版本和咨询操作历史。应用锁密码、备份密码和 AI 模型设置不写入备份。请把备份密码单独保管。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationSection: some View {
        Section("提醒诊断") {
            LabeledContent("系统权限", value: appState.notificationAuthorization)
            LabeledContent("本机待发送提醒", value: "\(pendingReminderCount) 条")
            Button("申请权限并发送 10 秒测试提醒") {
                Task { await sendDiagnosticNotification() }
            }
            .disabled(isWorking)
            Button("刷新提醒状态") {
                Task { await refreshNotificationStatus() }
            }
            Text("测试提醒不包含姓名、咨询主题或金额。正式预约提醒也只显示客户编号。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var audioDiagnosticSection: some View {
        Section("录音与本机转写自检") {
            LabeledContent("状态", value: audioSelfTest.isRecording ? "录音中" : (audioSelfTest.isTranscribing ? "转写中" : "待测试"))

            if audioSelfTest.isRecording {
                ProgressView(value: audioSelfTest.inputLevel)
                    .tint(BrandTheme.teal)
                    .accessibilityLabel("麦克风输入音量")
                Text("剩余 \(audioSelfTest.remainingSeconds) 秒")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    if audioSelfTest.isRecording {
                        await audioSelfTest.stopAndTranscribe()
                    } else {
                        await audioSelfTest.start()
                    }
                }
            } label: {
                Label(
                    audioSelfTest.isRecording ? "提前停止并转写" : "开始 10 秒录音测试",
                    systemImage: audioSelfTest.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                )
            }
            .disabled(audioSelfTest.isTranscribing)

            if audioSelfTest.canPlay {
                Button("回放本次测试录音", systemImage: "play.circle") {
                    audioSelfTest.play()
                }
            }

            if !audioSelfTest.transcript.isEmpty {
                LabeledContent("本机转写") {
                    Text(audioSelfTest.transcript)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }

            Text(audioSelfTest.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("测试录音只存在于内存和临时文件中，测试结束后自动删除，不进入客户资料，也不会上传云端。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var dataMaintenanceSection: some View {
        Section("本机资料维护") {
            LabeledContent("客户", value: "\(clients.count) 人")
            LabeledContent("预约", value: "\(appointments.count) 条")
            LabeledContent("咨询记录", value: "\(records.count) 条")
            LabeledContent("资料文件", value: "\(mediaAssets.count) 个")
            Button("清除所有演示数据", role: .destructive) {
                showingDemoClearConfirmation = true
            }
            Text("该操作只识别明确标记的演示数据，不提供模糊批量删除。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var versionSection: some View {
        Section("版本与升级") {
            LabeledContent("应用版本", value: appVersionText)
            LabeledContent("数据结构", value: "V\(AppMigrationService.currentVersion)")
            LabeledContent("升级状态", value: appState.migrationStatus)
            Text("数据库升级按版本顺序执行；升级成功后才写入版本标记。历史告知文本会自动补全而不会覆盖已有内容。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version)（\(build)）"
    }

    private func handleBackupDestination(_ result: Result<URL, Error>) {
        securityManager.resumeAutoLock()
        do {
            let folder = try result.get()
            isWorking = true
            statusMessage = "正在加密并校验备份…"
            let password = backupPassword
            Task {
                let granted = folder.startAccessingSecurityScopedResource()
                defer { if granted { folder.stopAccessingSecurityScopedResource() } }
                do {
                    let snapshot = try BackupService.captureSnapshot(context: context)
                    let package = try await BackupService.createBackup(snapshot: snapshot, password: password, destinationFolder: folder)
                    statusMessage = "加密备份已创建：\(package.lastPathComponent)"
                    backupPassword = ""
                    backupPasswordConfirmation = ""
                } catch {
                    statusMessage = error.localizedDescription
                }
                isWorking = false
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func handleValidationSelection(_ result: Result<URL, Error>) {
        securityManager.resumeAutoLock()
        do {
            let url = try result.get()
            let password = restorePassword
            isWorking = true
            statusMessage = "正在逐项验证备份…"
            Task {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                do {
                    let snapshot = try await BackupService.validateBackup(at: url, password: password)
                    statusMessage = "备份完整：\(snapshot.clients.count) 位客户、\(snapshot.appointments.count) 条预约、\(snapshot.mediaAssets.count) 个资料文件。"
                } catch {
                    statusMessage = error.localizedDescription
                }
                restorePassword = ""
                isWorking = false
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func handleRestoreSelection(_ result: Result<URL, Error>) {
        securityManager.resumeAutoLock()
        do {
            pendingRestoreURL = try result.get()
            showingRestoreConfirmation = true
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        let password = restorePassword
        isWorking = true
        statusMessage = "正在验证并准备恢复…"
        Task {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            do {
                let prepared = try await BackupService.prepareRestore(from: url, password: password)
                try BackupService.applyRestore(prepared, context: context)
                await BackupService.rebuildFutureReminders(context: context)
                statusMessage = "恢复完成并已重建未来预约提醒。"
            } catch {
                statusMessage = "恢复未完成：\(error.localizedDescription)"
            }
            restorePassword = ""
            pendingRestoreURL = nil
            isWorking = false
            await refreshNotificationStatus()
        }
    }

    private func clearDemoData() {
        do {
            let count = try TestDataService.clearDemoData(context: context)
            statusMessage = count == 0 ? "没有发现演示数据。" : "已清除 \(count) 条演示客户及关联记录。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendDiagnosticNotification() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let allowed = try await NotificationScheduler.requestAuthorization()
            guard allowed else {
                statusMessage = "通知权限未开启，请在系统设置中允许心塔发送通知。"
                await refreshNotificationStatus()
                return
            }
            try await NotificationScheduler.scheduleDiagnostic()
            statusMessage = "测试提醒已安排，将在约 10 秒后出现。"
            await refreshNotificationStatus()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let status = await NotificationScheduler.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral: appState.notificationAuthorization = "已允许"
        case .denied: appState.notificationAuthorization = "已关闭"
        case .notDetermined: appState.notificationAuthorization = "尚未申请"
        @unknown default: appState.notificationAuthorization = "未知"
        }
        pendingReminderCount = await NotificationScheduler.pendingReminderCount()
    }
}

private struct SecurityCredentialSheet: View {
    let mode: SecuritySheetMode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var securityManager: AppSecurityManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var enableBiometrics = true
    @State private var isWorking = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if mode == .change || mode == .disable {
                    SecureField("当前应用密码", text: $currentPassword)
                }
                if mode != .disable {
                    SecureField("新应用密码（至少 6 位）", text: $newPassword)
                    SecureField("再次输入新应用密码", text: $confirmation)
                    Toggle("启用 \(securityManager.biometryLabel)", isOn: $enableBiometrics)
                        .disabled(!securityManager.canUseBiometrics)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundStyle(.red)
                }
                Section {
                    Text(mode == .disable ? "关闭后，打开应用将不再要求身份验证。" : "密码仅用于本机应用锁，不会包含在业务备份中。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .disable ? "关闭" : "保存", role: mode == .disable ? .destructive : nil) {
                        performAction()
                    }
                    .disabled(isWorking || !isInputValid)
                }
            }
        }
        .compactNavigationTitleOnPhone()
        .adaptiveEditorSheet(macWidth: 410, macHeight: 360)
        .onAppear { enableBiometrics = securityManager.canUseBiometrics }
    }

    private var title: String {
        switch mode {
        case .enable: return "启用应用锁"
        case .change: return "修改应用密码"
        case .disable: return "关闭应用锁"
        }
    }

    private var isInputValid: Bool {
        if mode == .disable { return !currentPassword.isEmpty }
        let newValid = newPassword.count >= 6 && confirmation.count >= 6
        return mode == .change ? newValid && !currentPassword.isEmpty : newValid
    }

    private func performAction() {
        isWorking = true
        Task {
            do {
                if mode == .disable {
                    try await securityManager.disable(password: currentPassword)
                } else {
                    guard newPassword == confirmation else { throw AppSecurityError.confirmationMismatch }
                    if mode == .change {
                        guard try await securityManager.verify(password: currentPassword) else {
                            throw AppSecurityError.passwordMismatch
                        }
                    }
                    try await securityManager.configure(password: newPassword, enableBiometrics: enableBiometrics)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
