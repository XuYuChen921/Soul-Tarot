import Foundation
import SwiftData

enum AppModelContainer {
    #if DEBUG
    static let usesTemporaryTestStore: Bool = {
        let process = ProcessInfo.processInfo
        return process.environment["XCTestConfigurationFilePath"] != nil
            || process.arguments.contains(where: { $0.hasPrefix("--ui-testing") })
    }()
    #else
    static let usesTemporaryTestStore = false
    #endif

    static let shared: ModelContainer = {
        let schema = Schema([
            Client.self,
            ServiceItem.self,
            Appointment.self,
            ConsentRecord.self,
            ConsultationRecord.self,
            MediaAsset.self,
            PaymentTransaction.self,
            ServiceOrder.self,
            OrderPaymentTransaction.self,
            EntitlementRedemption.self,
            ServiceOrderChange.self,
            ConsultationActivity.self,
            ConsultationSummaryRevision.self
        ])
        let configuration = ModelConfiguration(
            "SoulTower",
            schema: schema,
            isStoredInMemoryOnly: usesTemporaryTestStore
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建心塔本地数据库：\(error.localizedDescription)")
        }
    }()
}
