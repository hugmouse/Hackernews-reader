import SwiftUI

struct CommentView: View {
  let comment: Comment
  let level: Int
  let highlightedCommentId: Int?
  let searchQuery: String
  @State private var showReplies = true
  @Environment(\.openWindow) private var openWindow

  init(comment: Comment, level: Int, highlightedCommentId: Int? = nil, searchQuery: String = "") {
    self.comment = comment
    self.level = level
    self.highlightedCommentId = highlightedCommentId
    self.searchQuery = searchQuery
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        if let username = comment.by {
          Button(username) {
            openWindow(id: "userProfile", value: username)
          }
          .fontWeight(.semibold)
          .buttonStyle(.link)
          .font(.subheadline)
          .accessibilityLabel("View profile for \(username)")
        } else {
          Text("dead")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        }

        Text(timeAgo(from: comment.time))
          .font(.caption)

        if let replies = comment.replies, !replies.isEmpty {
          Button(showReplies ? "[–]" : "[+]") {
            showReplies.toggle()
          }
          .font(.caption)
          .buttonStyle(.borderless)
          .accessibilityLabel(showReplies ? "Hide replies" : "Show replies")
          .accessibilityHint("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if let text = comment.text {
        VStack(alignment: .leading, spacing: 16) {
          HTMLTextView(html: text, highlightQuery: searchQuery)
        }
        .padding(.top, -4)
      }

      if showReplies, let replies = comment.replies, !replies.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(replies, id: \.id) { reply in
            CommentView(
              comment: reply, level: level + 1, highlightedCommentId: highlightedCommentId,
              searchQuery: searchQuery
            )
            .padding(.leading, 16)
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Replies to \(comment.by ?? "unknown user")")
      }
    }
    .background(Color.clear)
    .id("comment_\(comment.id)")
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      "Comment at level \(level + 1) by \(comment.by ?? "unknown user"), \(timeAgo(from: comment.time))"
    )
  }

  private func timeAgo(from timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

#Preview {
  let sampleComment = Comment(
    id: 1,
    by: "sample_user",
    time: Int(Date().timeIntervalSince1970) - 1800,
    text: """
      This is a sample comment with <em>formatting</em> and multiple lines of text to demonstrate how comments are displayed in the app.
      <p>Usually posts are formatted quite strangely.</p>Love when that happens.
      """,
    kids: [2, 3],
  )

  ScrollView {
    VStack(alignment: .leading, spacing: 8) {
      CommentView(comment: sampleComment, level: 0, highlightedCommentId: nil, searchQuery: "")
    }
    .padding()
  }
}
