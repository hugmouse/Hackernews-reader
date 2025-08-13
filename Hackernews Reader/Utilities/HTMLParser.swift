import Foundation

struct HTMLParser {
  static func stripHTML(_ html: String) -> String {
    guard let htmlStringData = html.data(using: String.Encoding.utf8) else {
      return html
    }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]

    let attributedString = try? NSAttributedString(
      data: htmlStringData, options: options, documentAttributes: nil)
    return attributedString?.string ?? html
  }
}
