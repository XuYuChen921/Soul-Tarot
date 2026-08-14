import Foundation
import UserNotifications

enum NotificationScheduler {
    static let diagnosticIdentifier = "soul-tower.notification-diagnostic"

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func schedule(for appointment: Appointment) async throws -> (String, String) {
        let center = UNUserNotificationCenter.current()
        let id24 = "appointment.\(appointment.id.uuidString).24h"
        let id1 = "appointment.\(appointment.id.uuidString).1h"
        center.removePendingNotificationRequests(withIdentifiers: [id24, id1])

        try await addRequest(
            identifier: id24,
            fireDate: appointment.startAt.addingTimeInterval(-24 * 60 * 60),
            title: "明天有咨询安排",
            body: "\(appointment.clientCode) · \(appointment.startAt.formatted(date: .omitted, time: .shortened)) · 请确认设备与资料"
        )
        try await addRequest(
            identifier: id1,
            fireDate: appointment.startAt.addingTimeInterval(-60 * 60),
            title: "1 小时后开始咨询",
            body: "\(appointment.clientCode) · 准备 \(appointment.videoDevice.rawValue)、客户简报和录音设备"
        )
        return (id24, id1)
    }

    static func cancel(for appointment: Appointment) {
        let identifiers = [appointment.reminder24Identifier, appointment.reminder1Identifier].filter { !$0.isEmpty }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func scheduleDiagnostic(after seconds: TimeInterval = 10) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [diagnosticIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "心塔提醒测试成功"
        content.body = "这是一条本机测试提醒，不包含任何客户资料。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        try await center.add(UNNotificationRequest(identifier: diagnosticIdentifier, content: content, trigger: trigger))
    }

    static func pendingReminderCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    static func cancelDiagnostic() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [diagnosticIdentifier])
    }

    private static func addRequest(identifier: String, fireDate: Date, title: String, body: String) async throws {
        guard fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["appointmentReminder": identifier]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
