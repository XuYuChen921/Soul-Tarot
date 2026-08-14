import Foundation
import SwiftData

enum TestDataService {
    @MainActor
    static func clearDemoData(context: ModelContext) throws -> Int {
        let clients = try context.fetch(FetchDescriptor<Client>())
        let demoClients = clients.filter { $0.clientCode == "C-DEMO" || $0.source == "演示数据" }
        let clientIDs = Set(demoClients.map(\.id))
        guard !clientIDs.isEmpty else { return 0 }

        let appointments = try context.fetch(FetchDescriptor<Appointment>()).filter { clientIDs.contains($0.clientID) }
        let appointmentIDs = Set(appointments.map(\.id))
        appointments.forEach(NotificationScheduler.cancel)

        let consents = try context.fetch(FetchDescriptor<ConsentRecord>()).filter {
            clientIDs.contains($0.clientID) || ($0.appointmentID.map(appointmentIDs.contains) ?? false)
        }
        let records = try context.fetch(FetchDescriptor<ConsultationRecord>()).filter { clientIDs.contains($0.clientID) }
        let payments = try context.fetch(FetchDescriptor<PaymentTransaction>()).filter {
            clientIDs.contains($0.clientID) || appointmentIDs.contains($0.appointmentID)
        }
        let orders = try context.fetch(FetchDescriptor<ServiceOrder>()).filter { clientIDs.contains($0.clientID) }
        let orderIDs = Set(orders.map(\.id))
        let orderPayments = try context.fetch(FetchDescriptor<OrderPaymentTransaction>()).filter {
            clientIDs.contains($0.clientID) || orderIDs.contains($0.orderID)
        }
        let redemptions = try context.fetch(FetchDescriptor<EntitlementRedemption>()).filter {
            clientIDs.contains($0.clientID) || orderIDs.contains($0.orderID) || appointmentIDs.contains($0.appointmentID)
        }
        let orderChanges = try context.fetch(FetchDescriptor<ServiceOrderChange>()).filter {
            clientIDs.contains($0.clientID) || orderIDs.contains($0.orderID)
        }
        let recordIDs = Set(records.map(\.id))
        let activities = try context.fetch(FetchDescriptor<ConsultationActivity>()).filter {
            clientIDs.contains($0.clientID) || recordIDs.contains($0.recordID)
        }
        let summaryRevisions = try context.fetch(FetchDescriptor<ConsultationSummaryRevision>()).filter {
            clientIDs.contains($0.clientID) || recordIDs.contains($0.recordID)
        }
        let assets = try context.fetch(FetchDescriptor<MediaAsset>()).filter {
            clientIDs.contains($0.clientID) || recordIDs.contains($0.sessionID)
        }

        for asset in assets {
            try? MediaStorageService.removeFile(relativePath: asset.relativePath)
            context.delete(asset)
        }
        consents.forEach(context.delete)
        activities.forEach(context.delete)
        summaryRevisions.forEach(context.delete)
        orderChanges.forEach(context.delete)
        redemptions.forEach(context.delete)
        orderPayments.forEach(context.delete)
        payments.forEach(context.delete)
        records.forEach(context.delete)
        appointments.forEach(context.delete)
        orders.forEach(context.delete)
        demoClients.forEach(context.delete)
        try context.save()
        return demoClients.count + appointments.count + records.count + activities.count + summaryRevisions.count + assets.count + payments.count + orders.count + orderPayments.count + redemptions.count + orderChanges.count
    }
}
