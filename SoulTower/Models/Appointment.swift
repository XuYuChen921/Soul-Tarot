import Foundation
import SwiftData

@Model
final class Appointment {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var clientCode: String
    var clientNameSnapshot: String
    var serviceID: UUID
    var serviceOrderID: UUID?
    var serviceNameSnapshot: String
    var startAt: Date
    var endAt: Date
    var statusRaw: String
    var paymentStatusRaw: String
    var videoDeviceRaw: String
    var priceCents: Int
    var policyVersion: String
    var reminder24Identifier: String
    var reminder1Identifier: String
    var guardianName: String
    var notes: String
    var changeCount: Int
    var createdAt: Date
    var updatedAt: Date

    var status: AppointmentStatus {
        get { AppointmentStatus(rawValue: statusRaw) ?? .pendingRules }
        set { statusRaw = newValue.rawValue }
    }

    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .unpaid }
        set { paymentStatusRaw = newValue.rawValue }
    }

    var videoDevice: VideoDevice {
        get { VideoDevice(rawValue: videoDeviceRaw) ?? .undecided }
        set { videoDeviceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        clientID: UUID,
        clientCode: String,
        clientNameSnapshot: String,
        serviceID: UUID,
        serviceOrderID: UUID? = nil,
        serviceNameSnapshot: String,
        startAt: Date,
        endAt: Date,
        status: AppointmentStatus = .confirmed,
        paymentStatus: PaymentStatus = .paid,
        videoDevice: VideoDevice = .undecided,
        priceCents: Int,
        policyVersion: String,
        guardianName: String = "",
        notes: String = "",
        changeCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.clientNameSnapshot = clientNameSnapshot
        self.serviceID = serviceID
        self.serviceOrderID = serviceOrderID
        self.serviceNameSnapshot = serviceNameSnapshot
        self.startAt = startAt
        self.endAt = endAt
        self.statusRaw = status.rawValue
        self.paymentStatusRaw = paymentStatus.rawValue
        self.videoDeviceRaw = videoDevice.rawValue
        self.priceCents = priceCents
        self.policyVersion = policyVersion
        self.reminder24Identifier = ""
        self.reminder1Identifier = ""
        self.guardianName = guardianName
        self.notes = notes
        self.changeCount = changeCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
