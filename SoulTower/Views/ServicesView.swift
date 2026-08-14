import SwiftData
import SwiftUI

struct ServicesView: View {
    @Query(sort: \ServiceItem.sortOrder) private var services: [ServiceItem]
    @State private var showingNewService = false
    @State private var editingService: ServiceItem?

    private var activeServices: [ServiceItem] { services.filter(\.isActive) }
    private var archivedServices: [ServiceItem] { services.filter { !$0.isActive } }
    private var categories: [String] {
        Array(Set(activeServices.map(\.category))).sorted { lhs, rhs in
            let left = activeServices.first(where: { $0.category == lhs })?.sortOrder ?? 0
            let right = activeServices.first(where: { $0.category == rhs })?.sortOrder ?? 0
            return left < right
        }
    }

    var body: some View {
        List {
            if activeServices.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: "还没有启用的产品",
                    message: "在这里建立自己的单次服务、次数套餐或长期项目；它们不属于任何客户。"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(categories, id: \.self) { category in
                Section(category) {
                    ForEach(activeServices.filter { $0.category == category }) { service in
                        Button { editingService = service } label: { serviceRow(service) }
                            .buttonStyle(.plain)
                    }
                }
            }

            if !archivedServices.isEmpty {
                Section("已归档") {
                    ForEach(archivedServices) { service in
                        Button { editingService = service } label: { serviceRow(service) }
                            .buttonStyle(.plain)
                            .opacity(0.65)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("产品与服务")
        .toolbar {
            Button { showingNewService = true } label: {
                Label("新建产品", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingNewService) { ServiceItemEditorView() }
        .sheet(item: $editingService) { service in
            ServiceItemEditorView(service: service)
        }
    }

    private func serviceRow(_ service: ServiceItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: service.productKind))
                .foregroundStyle(BrandTheme.teal)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name).font(.headline)
                HStack(spacing: 7) {
                    Text(service.productKind.rawValue)
                    Text(service.deliveryType.rawValue)
                    if service.durationMinutes > 0 { Text("约 \(service.durationMinutes) 分钟") }
                    if service.productKind == .package { Text("\(service.includedSessions) 次") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(priceText(service)).font(.headline)
                Text(service.isActive ? "已启用" : "已归档")
                    .font(.caption2)
                    .foregroundStyle(service.isActive ? .green : .secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
    }

    private func priceText(_ service: ServiceItem) -> String {
        switch service.pricingMode {
        case .fixed: return service.priceCents.yuanText
        case .startingAt: return "\(service.priceCents.yuanText) 起"
        case .perSquareMeter: return "\(service.priceCents.yuanText)/\(service.unitLabel)"
        }
    }

    private func icon(for kind: ProductKind) -> String {
        switch kind {
        case .singleConsultation: return "person.wave.2"
        case .package: return "repeat.circle.fill"
        case .project: return "doc.text.fill"
        }
    }
}

struct ServiceItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ServiceItem.sortOrder) private var allServices: [ServiceItem]

    private let service: ServiceItem?
    @State private var name: String
    @State private var category: String
    @State private var productKind: ProductKind
    @State private var deliveryType: DeliveryType
    @State private var durationText: String
    @State private var pricingMode: PricingMode
    @State private var priceText: String
    @State private var unitLabel: String
    @State private var sessionsText: String
    @State private var validDaysText: String
    @State private var requiresGuardian: Bool
    @State private var isActive: Bool
    @State private var ruleVersion: String
    @State private var errorMessage = ""

    init(service: ServiceItem? = nil) {
        self.service = service
        _name = State(initialValue: service?.name ?? "")
        _category = State(initialValue: service?.category ?? "心理成长")
        _productKind = State(initialValue: service?.productKind ?? .singleConsultation)
        _deliveryType = State(initialValue: service?.deliveryType ?? .video)
        _durationText = State(initialValue: String(service?.durationMinutes ?? 60))
        _pricingMode = State(initialValue: service?.pricingMode ?? .fixed)
        _priceText = State(initialValue: Self.yuanString(service?.priceCents ?? 0))
        _unitLabel = State(initialValue: service?.unitLabel ?? "㎡")
        _sessionsText = State(initialValue: String(service?.includedSessions ?? 1))
        _validDaysText = State(initialValue: String(service?.validDays ?? 0))
        _requiresGuardian = State(initialValue: service?.requiresGuardian ?? false)
        _isActive = State(initialValue: service?.isActive ?? true)
        _ruleVersion = State(initialValue: service?.ruleVersion ?? DefaultBusinessRules.policyVersion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("产品定义") {
                    TextField("名称", text: $name)
                    TextField("分类", text: $category)
                    Picker("产品类型", selection: $productKind) {
                        ForEach(ProductKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("交付方式", selection: $deliveryType) {
                        ForEach(DeliveryType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if productKind != .project {
                        TextField("单次时长（分钟）", text: $durationText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    }
                }

                Section("目录价格") {
                    Picker("计价方式", selection: $pricingMode) {
                        ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("价格（元）", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    if pricingMode == .perSquareMeter {
                        TextField("计价单位", text: $unitLabel)
                    }
                }

                if productKind == .package {
                    Section("套餐权益") {
                        TextField("包含次数", text: $sessionsText)
                        TextField("激活后有效天数（0 为不限）", text: $validDaysText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        Text("有效期从客户订单达到激活条件时开始，不从建立产品或未付款下单时开始。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if productKind == .project {
                    Section("项目限制") {
                        Toggle("必须由监护人提起", isOn: $requiresGuardian)
                    }
                }

                Section("管理") {
                    Toggle("在目录中启用", isOn: $isActive)
                    TextField("规则版本", text: $ruleVersion)
                    Text("归档不会删除历史客户订单中的产品快照。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(service == nil ? "新建产品" : "编辑产品")
            .compactNavigationTitleOnPhone()
            .onChange(of: productKind) { _, value in
                if value == .project {
                    deliveryType = .project
                    durationText = "0"
                    sessionsText = "1"
                    validDaysText = "0"
                } else if value == .singleConsultation {
                    if deliveryType == .project { deliveryType = .video }
                    sessionsText = "1"
                    validDaysText = "0"
                    requiresGuardian = false
                } else if deliveryType == .project {
                    deliveryType = .video
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存产品") { save() } }
            }
        }
        .adaptiveEditorSheet(macWidth: 470, macHeight: 650)
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanCategory.isEmpty else {
            errorMessage = "请填写产品名称和分类。"
            return
        }
        guard let priceCents = PaymentLedgerService.yuanTextToCents(priceText) else {
            errorMessage = "请输入有效价格。"
            return
        }
        let duration = productKind == .project ? 0 : max(Int(durationText) ?? 0, 1)
        let sessions = productKind == .package ? max(Int(sessionsText) ?? 0, 1) : 1
        let validDays = productKind == .package ? max(Int(validDaysText) ?? 0, 0) : 0
        let cleanUnit = pricingMode == .perSquareMeter
            ? unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        guard pricingMode != .perSquareMeter || !cleanUnit.isEmpty else {
            errorMessage = "按量计价时必须填写计价单位。"
            return
        }

        if let service {
            service.name = cleanName
            service.category = cleanCategory
            service.productKind = productKind
            service.deliveryType = productKind == .project ? .project : deliveryType
            service.durationMinutes = duration
            service.pricingMode = pricingMode
            service.priceCents = priceCents
            service.unitLabel = cleanUnit
            service.includedSessions = sessions
            service.validDays = validDays
            service.requiresGuardian = productKind == .project && requiresGuardian
            service.isActive = isActive
            service.ruleVersion = ruleVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            context.insert(ServiceItem(
                category: cleanCategory,
                name: cleanName,
                productKind: productKind,
                deliveryType: productKind == .project ? .project : deliveryType,
                durationMinutes: duration,
                pricingMode: pricingMode,
                priceCents: priceCents,
                unitLabel: cleanUnit,
                includedSessions: sessions,
                validDays: validDays,
                requiresGuardian: productKind == .project && requiresGuardian,
                isActive: isActive,
                sortOrder: (allServices.map(\.sortOrder).max() ?? 0) + 1,
                ruleVersion: ruleVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private static func yuanString(_ cents: Int) -> String {
        NSDecimalNumber(value: cents).dividing(by: 100).stringValue
    }
}
