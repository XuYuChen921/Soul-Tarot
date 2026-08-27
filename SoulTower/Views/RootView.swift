import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "工作台"
    case clients = "客户"
    case schedule = "排期"
    case records = "咨询资料"
    case ai = "AI 整理"
    case business = "经营总览"
    case brandGrowth = "品牌增长"
    case orders = "客户订单"
    case services = "产品与服务"
    case safety = "安全中心"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "sparkles.rectangle.stack"
        case .clients: return "person.2"
        case .schedule: return "calendar"
        case .records: return "folder"
        case .ai: return "wand.and.stars"
        case .business: return "chart.bar.xaxis"
        case .brandGrowth: return "sparkles"
        case .orders: return "shippingbox"
        case .services: return "square.grid.2x2"
        case .safety: return "lock.shield"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        Group {
            #if os(iOS)
            phoneRoot
            #else
            desktopRoot
            #endif
        }
        .tint(BrandTheme.teal)
    }

    #if os(iOS)
    private var phoneRoot: some View {
        TabView {
            phoneContainer { DashboardView() }
                .tabItem { Label("工作台", systemImage: AppSection.dashboard.icon) }

            phoneContainer { ClientsView() }
                .tabItem { Label("客户", systemImage: AppSection.clients.icon) }

            phoneContainer { ScheduleView() }
                .tabItem { Label("排期", systemImage: AppSection.schedule.icon) }

            phoneContainer { RecordsView() }
                .tabItem { Label("资料", systemImage: AppSection.records.icon) }

            phoneContainer { PhoneMoreView() }
                .tabItem { Label("更多", systemImage: "ellipsis.circle") }
        }
    }

    private func phoneContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                content()
            }
        }
    }
    #else
    private var desktopRoot: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("心塔")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("心理成长工作台")
                        .font(.caption.weight(.semibold))
                    Text("本地优先 · V\(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        } detail: {
            NavigationStack {
                ZStack {
                    BrandBackground()
                    selectedView
                }
            }
            // 客户详情等页面会压入当前导航栈；切换左侧栏目时重建栈，
            // 确保详情页不会覆盖新选择的工作台、排期或其他栏目。
            .id(selectedSection ?? .dashboard)
        }
    }
    #endif

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedSection ?? .dashboard {
        case .dashboard: DashboardView()
        case .clients: ClientsView()
        case .schedule: ScheduleView()
        case .records: RecordsView()
        case .ai: AIWorkspaceView()
        case .business: BusinessView()
        case .brandGrowth: BrandGrowthView()
        case .orders: ServiceOrdersView()
        case .services: ServicesView()
        case .safety: SafetyCenterView()
        case .settings: SettingsView()
        }
    }
}

#if os(iOS)
private struct PhoneMoreView: View {
    var body: some View {
        List {
            Section("隐私与提醒") {
                NavigationLink {
                    SafetyCenterView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("安全中心")
                                .font(.headline)
                            Text("应用锁、加密备份、提醒和录音自检")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: AppSection.safety.icon)
                            .foregroundStyle(BrandTheme.teal)
                    }
                }
            }

            Section("其他工具") {
                NavigationLink { ServiceOrdersView() } label: {
                    Label("客户订单", systemImage: AppSection.orders.icon)
                }
                NavigationLink { BusinessView() } label: {
                    Label("经营总览", systemImage: AppSection.business.icon)
                }
                NavigationLink { BrandGrowthView() } label: {
                    Label("品牌增长", systemImage: AppSection.brandGrowth.icon)
                }
                NavigationLink { AIWorkspaceView() } label: {
                    Label("AI 整理", systemImage: AppSection.ai.icon)
                }
                NavigationLink { ServicesView() } label: {
                    Label("产品与服务", systemImage: AppSection.services.icon)
                }
                NavigationLink { SettingsView() } label: {
                    Label("设置", systemImage: AppSection.settings.icon)
                }
            }
        }
        .navigationTitle("更多")
    }
}
#endif
