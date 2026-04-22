import UserNotifications
import Foundation

final class LocalNotificationService {
    static let shared = LocalNotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return (try? await center.requestAuthorization(options: options)) ?? false
    }

    func scheduleDaily(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        weekdays: [Int]     // 1=Sun, 2=Mon, ... 7=Sat (Calendar)
    ) {
        cancel(identifier: identifier)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        for weekday in weekdays {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(identifier)-\(weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancel(identifier: String) {
        let ids = (1...7).map { "\(identifier)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // Convert Korean day names to Calendar weekday numbers
    static func toWeekdays(_ days: [String]) -> [Int] {
        let map: [String: Int] = ["일": 1, "월": 2, "화": 3, "수": 4, "목": 5, "금": 6, "토": 7]
        return days.compactMap { map[$0] }
    }
}
