import SwiftUI

struct StoryHeaderView: View {
  let story: Story
  @Environment(\.openWindow) private var openWindow

  private func combinedTitleWithURL() -> AttributedString {
    var title = AttributedString(story.title)
    title.font = .title.weight(.bold)

    if let url = story.url, !url.isEmpty {
      let host = URL(string: url)?.host() ?? "Invalid URL"
      var urlText = AttributedString(" (\(host))")
      urlText.font = .title2
      urlText.foregroundColor = .secondary

      return title + urlText
    }

    return title
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(combinedTitleWithURL())

      HStack(spacing: 4) {
        Text("\(story.score) points")

        HStack(alignment: .center, spacing: 2) {
          Text("by")
          Button(story.by) {
            openWindow(id: "userProfile", value: story.by)
          }
          .fontWeight(.semibold)
          .buttonStyle(.link)
          .accessibilityLabel("View profile for \(story.by)")
        }

        Text(TimeFormatter.relativeTimeString(from: story.time))

        Spacer()

        Link(
          "Open HN", destination: URL(string: "https://news.ycombinator.com/item?id=\(story.id)")!
        )
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .accessibilityLabel("Open story on Hacker News")

        if let url = story.url, !url.isEmpty {
          Link("Open Link", destination: URL(string: url)!)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Open original story link")
        }
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
  }
}
