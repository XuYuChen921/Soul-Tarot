import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var localMessage = ""
    @State private var checkingAI = false

    var body: some View {
        Form {
            Section("本地优先") {
                LabeledContent("资料处理", value: "仅本机")
                LabeledContent("云端同步", value: "关闭")
                LabeledContent("微信自动读取", value: "不启用")
                Text("客户资料、录音、照片和 AI 草稿不自动上传云端。需要跨设备时，首版以分别运行和人工导入为主。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("提醒") {
                LabeledContent("默认提醒", value: "提前 24 小时、1 小时")
                LabeledContent("提醒对象", value: "仅咨询师本人")
                LabeledContent("系统权限", value: appState.notificationAuthorization)
                Button("检查并申请通知权限") {
                    Task { await checkNotifications() }
                }
            }

            Section("本地 AI（Mac）") {
                #if os(macOS)
                LabeledContent("本机统一内存", value: "\(LocalAIModelPolicy.deviceMemoryGiB) GB")
                LabeledContent("按配置推荐", value: LocalAIModelPolicy.recommendedModel)
                #endif
                TextField("本地服务地址", text: $appState.aiBaseURL)
                TextField("模型名称", text: $appState.aiModelName)
                #if os(macOS)
                Button("使用本机推荐模型") {
                    appState.aiModelName = LocalAIModelPolicy.recommendedModel
                    appState.aiConnectionStatus = "已选择推荐模型，请检测是否已安装"
                }
                #endif
                LabeledContent("连接状态", value: appState.aiConnectionStatus)
                Button(checkingAI ? "正在检测…" : "检测本地 AI") {
                    Task { await checkAI() }
                }
                .disabled(checkingAI)
                Text("安全限制：只允许连接 127.0.0.1、localhost 或 ::1。即使本地模型未安装，其他业务功能仍可使用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #if os(macOS)
                Text(LocalAIModelPolicy.recommendationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("规则版本") {
                TextField("服务规则", text: $appState.policyVersion)
                TextField("录音同意", text: $appState.recordingConsentVersion)
                TextField("牌阵照片同意", text: $appState.photoConsentVersion)
                TextField("本地 AI 同意", text: $appState.aiConsentVersion)
                TextField("长期保存同意", text: $appState.retentionConsentVersion)
                Text("修改版本只作用于后续新预约；历史记录保留当时使用的版本。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("当前开发默认值") {
                LabeledContent("预约时段", value: "10:00-12:00、16:00-20:00")
                LabeledContent("预约缓冲", value: "15 分钟")
                LabeledContent("晚改期费用", value: DefaultBusinessRules.lateRescheduleFeeCents.yuanText)
                LabeledContent("加急费", value: DefaultBusinessRules.expeditedFeeCents.yuanText)
                DisclosureGroup("默认项目订单规则") {
                    Text(DefaultBusinessRules.projectOrderPolicySummary).font(.footnote).textSelection(.enabled)
                }
                DisclosureGroup("默认套餐售后与变更规则") {
                    Text(DefaultBusinessRules.packageAfterSalePolicySummary).font(.footnote).textSelection(.enabled)
                }
                DisclosureGroup("默认咨询资料归档规则") {
                    Text(DefaultBusinessRules.consultationArchivePolicySummary).font(.footnote).textSelection(.enabled)
                }
                DisclosureGroup("长期保存告知摘要") {
                    Text(DefaultBusinessRules.retentionNotice)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                DisclosureGroup("默认录音告知") {
                    Text(DefaultBusinessRules.recordingConsentNotice).font(.footnote).textSelection(.enabled)
                }
                DisclosureGroup("默认本地 AI 告知") {
                    Text(DefaultBusinessRules.localAIConsentNotice).font(.footnote).textSelection(.enabled)
                }
                DisclosureGroup("默认牌阵照片告知") {
                    Text(DefaultBusinessRules.photoConsentNotice).font(.footnote).textSelection(.enabled)
                }
            }

            if !localMessage.isEmpty { Section { Text(localMessage).foregroundStyle(.secondary) } }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .task { await refreshNotificationStatus() }
    }

    @MainActor
    private func checkNotifications() async {
        do {
            _ = try await NotificationScheduler.requestAuthorization()
            await refreshNotificationStatus()
        } catch {
            localMessage = error.localizedDescription
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
    }

    @MainActor
    private func checkAI() async {
        checkingAI = true
        defer { checkingAI = false }
        do {
            appState.aiConnectionStatus = try await LocalAIService().checkConnection(baseURL: appState.aiBaseURL, expectedModel: appState.aiModelName)
        } catch {
            appState.aiConnectionStatus = error.localizedDescription
        }
    }
}
