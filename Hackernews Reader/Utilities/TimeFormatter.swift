import Foundation

struct TimeFormatter {
  static func timeAgoString(from timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let now = Date()
    let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

    if let days = components.day, days > 0 {
      return "\(days)d ago"
    } else if let hours = components.hour, hours > 0 {
      return "\(hours)h ago"
    } else if let minutes = components.minute, minutes > 0 {
      return "\(minutes)m ago"
    } else {
      return "now"
    }
  }

  static func relativeTimeString(from timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}
