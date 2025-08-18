import AppKit
import Foundation
import SwiftUI

struct HTMLTextView: View {
  let html: String
  let highlightQuery: String
  
  private static var hasWarmStart = false

  init(html: String, highlightQuery: String = "") {
    self.html = html
    self.highlightQuery = highlightQuery
  }
  
  // "Pre-warms" the HTML rendering engine to avoid cold start delays
  // I honestly have no idea why it ultimately fixes NSAttributedString creation time
  // This delay can be seen in SwiftUI profiler, in timing summary for HTMLTextView
  // TODO: Investigate this deeper
  static func preWarmHTMLEngine() {
    guard !hasWarmStart else { return }
    
    let dummyHTML = "<p>:(</p>"
    
    if let data = dummyHTML.data(using: .utf8) {
      do {
        _ = try NSAttributedString(
          data: data,
          options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
          ],
          documentAttributes: nil
        )
        hasWarmStart = true
      } catch {
        print("[HTMLTextView] Failed to pre-warm HTML engine: \(error)")
      }
    }
  }

  var body: some View {
    Text(attributedString)
      .font(.body)
      .textSelection(.enabled)
  }
    

  private var attributedString: AttributedString {
    let overallStartTime = CFAbsoluteTimeGetCurrent()
    
    do {
      let htmlModStartTime = CFAbsoluteTimeGetCurrent()
      // Adding some space between the lines
      // Waiting for this to destroy the view in the near future
      let modifiedHTML =
        html
        .replacingOccurrences(of: "<p>", with: "<br><br><p>")
        .replacingOccurrences(of: "</pre>", with: "</pre><br>")
        .replacingOccurrences(of: "<br><p><pre>", with: "<p><pre>")

      guard let data = modifiedHTML.data(using: .utf8) else {
        return AttributedString(html)
      }

      let isFirstRender = !Self.hasWarmStart
      let nsAttributedString = try NSMutableAttributedString(
        data: data,
        options: [
          .documentType: NSAttributedString.DocumentType.html,
          .characterEncoding: String.Encoding.utf8.rawValue,
        ],
        documentAttributes: nil
      )
      
      if !Self.hasWarmStart {
        Self.hasWarmStart = true
      }

      let fullRange = NSRange(location: 0, length: nsAttributedString.length)

    nsAttributedString.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            if let originalFont = attrs[.font] as? NSFont {
                let symbolicTraits = originalFont.fontDescriptor.symbolicTraits
                let newBaseFont: NSFont

                if symbolicTraits.contains(.monoSpace) {
                    newBaseFont = .monospacedSystemFont(ofSize: originalFont.pointSize, weight: .regular)
                } else {
                    newBaseFont = .systemFont(ofSize: originalFont.pointSize)
                }

                let newDescriptor = newBaseFont.fontDescriptor.withSymbolicTraits(symbolicTraits)
                let newFont = NSFont(descriptor: newDescriptor, size: NSFont.systemFontSize) ?? newBaseFont
                nsAttributedString.addAttribute(.font, value: newFont, range: range)
            }

            if attrs[.link] != nil {
                nsAttributedString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            }
        }

      // Trim trailing whitespace
      let string = nsAttributedString.string
      if let trimRange = string.rangeOfCharacter(
        from: .whitespacesAndNewlines.inverted, options: .backwards)
      {
        let rangeToDelete = NSRange(trimRange.upperBound..<string.endIndex, in: string)
        if rangeToDelete.length > 0 {
          nsAttributedString.deleteCharacters(in: rangeToDelete)
        }
      } else {
        nsAttributedString.deleteCharacters(in: fullRange)
      }

      if !highlightQuery.isEmpty {
        addSearchHighlighting(to: nsAttributedString, query: highlightQuery)
      }

      return AttributedString(nsAttributedString)

    } catch {
      return AttributedString(html)
    }
  }

  private func addSearchHighlighting(to attributedString: NSMutableAttributedString, query: String)
  {
    let string = attributedString.string.lowercased()
    let searchQuery = query.lowercased()

    var searchRange = NSRange(location: 0, length: string.count)
    while searchRange.location < string.count {
      let foundRange = (string as NSString).range(of: searchQuery, options: [], range: searchRange)
      if foundRange.location == NSNotFound {
        break
      }

      // Apply highlighting
      attributedString.addAttribute(
        .backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: foundRange)
      attributedString.addAttribute(.foregroundColor, value: NSColor.black, range: foundRange)

      // Move search range to continue looking
      searchRange.location = foundRange.location + foundRange.length
      searchRange.length = string.count - searchRange.location
    }
  }
}
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      HTMLTextView(
        html: """
          I just searched within the (edit: iOS App Store) App Store app for<p><pre><code>     ublock origin lite\n    “ublock origin lite”\n</code></pre>\nFor the unquoted search, there are twelve different apps&#x2F;items returned above it - you really have to scroll down to find it at number 13.<p><i>Even for the quoted search, it’s returned in fourth place.</i><p>More interestingly the second time I searched with quoted it’s in third place, and the third time of searching the sponsored items at the top is getting even more random.
          """)
    }
  }
  .padding()
}
