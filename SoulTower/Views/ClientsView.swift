import SwiftUI
import SwiftData

struct ClientsView: View {
    @Query(sort: \Client.createdAt, order: .reverse) private var clients: [Client]
    @State private var searchText = ""
    @State private var showingEditor = false

    private var filteredClients: [Client] {
        let active = clients.filter { !$0.isArchived }
        guard !searchText.isEmpty else { return active }
        return active.filter {
            $0.clientCode.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.wechatNickname.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if clients.isEmpty {
                EmptyStateView(icon: "person.2", title: "还没有客户", message: "新建客户后，就能安排预约和归档咨询资料。")
            } else {
                List(filteredClients) { client in
                    NavigationLink {
                        ClientDetailView(client: client)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(BrandTheme.mint)
                                .frame(width: 42, height: 42)
                                .overlay(Text(client.displayName.prefix(1)).foregroundStyle(BrandTheme.deepGreen).font(.headline))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(client.displayName).font(.headline)
                                Text("\(client.clientCode) · \(client.source)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !client.wechatNickname.isEmpty {
                                Text("微信：\(client.wechatNickname)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("客户")
        .searchable(text: $searchText, prompt: "客户编号、称呼或微信昵称")
        .toolbar {
            Button { showingEditor = true } label: { Label("新建客户", systemImage: "plus") }
        }
        .sheet(isPresented: $showingEditor) { ClientEditorView() }
    }
}

struct ClientDetailView: View {
    let client: Client
    @Query private var appointments: [Appointment]
    @Query private var records: [ConsultationRecord]
    @Query private var orders: [ServiceOrder]
    @State private var showingEditor = false
    @State private var showingOrderEditor = false

    init(client: Client) {
        self.client = client
        let id = client.id
        _appointments = Query(filter: #Predicate<Appointment> { $0.clientID == id }, sort: \Appointment.startAt, order: .reverse)
        _records = Query(filter: #Predicate<ConsultationRecord> { $0.clientID == id }, sort: \ConsultationRecord.occurredAt, order: .reverse)
        _orders = Query(filter: #Predicate<ServiceOrder> { $0.clientID == id }, sort: \ServiceOrder.placedAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Circle().fill(BrandTheme.mint).frame(width: 68, height: 68)
                        .overlay(Text(client.displayName.prefix(1)).font(.title.bold()).foregroundStyle(BrandTheme.deepGreen))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.displayName).font(.title.bold())
                        Text("\(client.clientCode) · 来源：\(client.source)").foregroundStyle(.secondary)
                    }
                }
                GroupBox("基本资料") {
                    LabeledContent("微信昵称", value: client.wechatNickname.isEmpty ? "未填写" : client.wechatNickname)
                    LabeledContent("电话", value: client.phone.isEmpty ? "未填写" : client.phone)
                    LabeledContent("备注", value: client.notes.isEmpty ? "无" : client.notes)
                }
                GroupBox("预约记录") {
                    if appointments.isEmpty { Text("暂无预约").foregroundStyle(.secondary) }
                    ForEach(appointments) { AppointmentRow(appointment: $0) }
                }
                GroupBox("客户订单") {
                    if orders.isEmpty { Text("暂无套餐或项目订单").foregroundStyle(.secondary) }
                    ForEach(orders) { order in
                        NavigationLink {
                            ServiceOrderDetailView(order: order)
                        } label: {
                            HStack {
                                Text(order.serviceNameSnapshot)
                                Spacer()
                                StatusBadge(text: order.status.rawValue, color: order.status == .active ? .green : .orange)
                            }
                        }
                    }
                }
                GroupBox("咨询资料") {
                    if records.isEmpty { Text("暂无咨询资料").foregroundStyle(.secondary) }
                    ForEach(records) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            HStack {
                                Text("\(record.occurredAt.formatted(date: .abbreviated, time: .omitted)) · \(record.serviceName)")
                                Spacer()
                                if record.archivedAt != nil {
                                    StatusBadge(text: "已归档", color: .green)
                                } else {
                                    StatusBadge(text: record.aiStatus.rawValue, color: record.aiStatus.color)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(client.clientCode)
        .toolbar {
            Button("新建订单") { showingOrderEditor = true }
            Button("编辑") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) { ClientEditorView(client: client) }
        .sheet(isPresented: $showingOrderEditor) { ServiceOrderEditorView(client: client) }
    }
}

struct ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var clients: [Client]
    private let client: Client?
    @State private var displayName: String
    @State private var wechatNickname: String
    @State private var phone: String
    @State private var source: String
    @State private var notes: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date

    init(client: Client? = nil) {
        self.client = client
        _displayName = State(initialValue: client?.displayName ?? "")
        _wechatNickname = State(initialValue: client?.wechatNickname ?? "")
        _phone = State(initialValue: client?.phone ?? "")
        _source = State(initialValue: client?.source ?? "熟人介绍")
        _notes = State(initialValue: client?.notes ?? "")
        _hasBirthDate = State(initialValue: client?.birthDate != nil)
        _birthDate = State(initialValue: client?.birthDate ?? Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("必要信息") {
                    LabeledContent("客户编号", value: client?.clientCode ?? nextClientCode)
                    TextField("客户称呼", text: $displayName)
                    TextField("微信昵称", text: $wechatNickname)
                    Toggle("填写阳历出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("阳历出生日期", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    }
                }
                Section("可选信息") {
                    TextField("手机号", text: $phone)
                    TextField("来源", text: $source)
                    TextField("备注", text: $notes, axis: .vertical)
                }
                Section {
                    Text("真实姓名和出生日期只在确有业务必要时填写；提醒和日历只使用客户编号。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(client == nil ? "新建客户" : "编辑客户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let client {
                            client.displayName = displayName.trimmingCharacters(in: .whitespaces)
                            client.wechatNickname = wechatNickname
                            client.phone = phone
                            client.source = source
                            client.birthDate = hasBirthDate ? birthDate : nil
                            client.notes = notes
                            client.updatedAt = .now
                        } else {
                            context.insert(Client(clientCode: nextClientCode, displayName: displayName.trimmingCharacters(in: .whitespaces), wechatNickname: wechatNickname, phone: phone, source: source, birthDate: hasBirthDate ? birthDate : nil, notes: notes))
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .compactNavigationTitleOnPhone()
        .adaptiveEditorSheet(macWidth: 410, macHeight: 460)
    }

    private var nextClientCode: String {
        let number = clients.compactMap { Int($0.clientCode.replacingOccurrences(of: "C-", with: "")) }.max() ?? 0
        return String(format: "C-%04d", number + 1)
    }
}
