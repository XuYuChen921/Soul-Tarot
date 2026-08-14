import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var appointments: [Appointment]
    @Query private var clients: [Client]
    @Query private var records: [ConsultationRecord]
    @State private var showingNewAppointment = false
    @State private var showingNewClient = false
    @State private var showingVoiceIntake = false
    @State private var showingNewOrder = false
    @State private var seedMessage = ""

    private var todayAppointments: [Appointment] {
        appointments
            .filter {
                $0.startAt >= Date.now.dayStart &&
                $0.startAt <= Date.now.dayEnd &&
                ![.cancelled, .rescheduled].contains($0.status)
            }
            .sorted { $0.startAt < $1.startAt }
    }

    private var pendingPayments: Int {
        appointments.filter { $0.paymentStatus == .unpaid && $0.status != .cancelled }.count
    }

    private var pendingReviews: Int {
        records.filter { $0.aiStatus == .draft || $0.aiStatus == .ready }.count
    }

    private var nextAppointment: Appointment? {
        appointments
            .filter { $0.startAt > .now && $0.status == .confirmed }
            .sorted { $0.startAt < $1.startAt }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                metrics
                nextSection
                todaySection
                privacyStrip
            }
            .padding()
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .navigationTitle("今日工作台")
        .sheet(isPresented: $showingNewAppointment) { AppointmentEditorView() }
        .sheet(isPresented: $showingNewClient) { ClientEditorView() }
        .sheet(isPresented: $showingNewOrder) { ServiceOrderEditorView() }
        #if os(macOS)
        .sheet(isPresented: $showingVoiceIntake) { VoiceIntakeView() }
        #endif
    }

    @ViewBuilder
    private var header: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 14) {
                headerTitle(compact: true)
                HStack(spacing: 10) {
                    Button { showingNewClient = true } label: {
                        Label("新建客户", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { showingNewAppointment = true } label: {
                        Label("新建预约", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button { showingNewOrder = true } label: {
                    Label("新建客户订单", systemImage: "shippingbox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } else {
            HStack(alignment: .center, spacing: 16) {
                headerTitle(compact: false)
                Spacer()
                #if os(macOS)
                Button { showingVoiceIntake = true } label: {
                    Label("语音建档", systemImage: "waveform.and.mic")
                }
                .buttonStyle(.borderedProminent)
                #endif
                Button { showingNewClient = true } label: {
                    Label("新建客户", systemImage: "person.badge.plus")
                }
                Button { showingNewOrder = true } label: {
                    Label("新建客户订单", systemImage: "shippingbox")
                }
                Button { showingNewAppointment = true } label: {
                    Label("新建预约", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func headerTitle(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day().weekday(.wide)))
                .foregroundStyle(.secondary)
            Text("把今天的咨询安排好")
                .font(compact ? .title2.bold() : .largeTitle.bold())
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            MetricCard(title: "今日咨询", value: "\(todayAppointments.count)", note: "场", icon: "video")
            MetricCard(title: "待确认付款", value: "\(pendingPayments)", note: "笔", icon: "creditcard", tint: .orange)
            MetricCard(title: "待校对摘要", value: "\(pendingReviews)", note: "份", icon: "text.badge.checkmark", tint: .purple)
            MetricCard(title: "客户总数", value: "\(clients.filter { !$0.isArchived }.count)", note: "人", icon: "person.2", tint: .blue)
        }
    }

    @ViewBuilder
    private var nextSection: some View {
        if let appointment = nextAppointment {
            VStack(alignment: .leading, spacing: 12) {
                Text("下一场咨询")
                    .font(.title2.bold())
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(BrandTheme.mint)
                        Image(systemName: appointment.videoDevice == .iPhone ? "iphone" : "laptopcomputer")
                            .font(.system(size: 30))
                            .foregroundStyle(BrandTheme.deepGreen)
                    }
                    .frame(width: 66, height: 66)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(appointment.clientCode) · \(appointment.serviceNameSnapshot)")
                            .font(.headline)
                        Text(appointment.startAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                        Text("设备：\(appointment.videoDevice.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: appointment.paymentStatus.rawValue, color: appointment.paymentStatus == .paid ? .green : .orange)
                    Button("进入准备") { }
                        .buttonStyle(.borderedProminent)
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日排期")
                .font(.title2.bold())
            if todayAppointments.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateView(icon: "calendar", title: "今天还没有预约", message: "可以直接新建客户和预约，或插入一条演示数据体验完整流程。")
                    if clients.isEmpty {
                        Button("插入演示数据") {
                            do {
                                try SeedService.insertDemoData(context: context)
                                seedMessage = "演示数据已创建"
                            } catch {
                                seedMessage = error.localizedDescription
                            }
                        }
                        .buttonStyle(.bordered)
                        if !seedMessage.isEmpty { Text(seedMessage).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(todayAppointments) { appointment in
                    AppointmentRow(appointment: appointment)
                }
            }
        }
    }

    private var privacyStrip: some View {
        Label("本地优先模式已启用：客户资料不会自动上传云端，锁屏提醒仅显示客户编号。", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(BrandTheme.deepGreen)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandTheme.mint.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AppointmentRow: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(appointment.startAt.formatted(date: .omitted, time: .shortened))
                    .font(.headline.monospacedDigit())
                Text("\(Int(appointment.endAt.timeIntervalSince(appointment.startAt) / 60)) 分钟")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 82)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(appointment.clientCode) · \(appointment.serviceNameSnapshot)")
                    .font(.headline)
                Text("\(appointment.videoDevice.rawValue) · \(appointment.priceCents.yuanText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: appointment.status.rawValue, color: appointment.status.color)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
    }
}
